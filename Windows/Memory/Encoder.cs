using System;
using System.Diagnostics;
using System.Linq;
using System.Threading.Tasks;
using Windows.Foundation;
using Windows.Graphics.Capture;
using Windows.Graphics.DirectX.Direct3D11;
using Windows.Media.Core;
using Windows.Media.MediaProperties;
using Windows.Media.Transcoding;
using Windows.Storage.Streams;

namespace PreProcessEncoder
{
    public sealed class Encoder : IDisposable
    {
        public Encoder(GraphicsCaptureItem item)
        {
            _captureItem = item;
            _isRecording = false;

            CreateMediaObjects();
        }

        public IAsyncAction EncodeAsync(IRandomAccessStream stream, uint width, uint height, uint bitrateInBps, double frameRate)
        {
            return EncodeInternalAsync(stream, width, height, bitrateInBps, frameRate).AsAsyncAction();
        }

        private async Task EncodeInternalAsync(IRandomAccessStream stream, uint width, uint height, uint bitrateInBps, double frameRate)
        {
            if (!_isRecording)
            {
                _isRecording = true;

                _frameGenerator = new CaptureFrameWait(
                    _captureItem,
                    _captureItem.Size);

                using (_frameGenerator)
                {
                    CodecQuery codecQuery = new CodecQuery();
                    bool haveEncoder = (await codecQuery.FindAllAsync(CodecKind.Video, CodecCategory.Encoder, "hevc")).Any();
                    bool haveDecoder = (await codecQuery.FindAllAsync(CodecKind.Video, CodecCategory.Decoder, "hevc")).Any();
                    bool useHEVC = haveEncoder && haveDecoder;
                    var encodingProfile = useHEVC ? MediaEncodingProfile.CreateHevc(VideoEncodingQuality.HD1080p) : MediaEncodingProfile.CreateMp4(VideoEncodingQuality.HD1080p);
                    encodingProfile.Video.Width = width;
                    encodingProfile.Video.Height = height;
                    encodingProfile.Video.FrameRate.Numerator = 1;
                    encodingProfile.Video.FrameRate.Denominator = 2;
                    encodingProfile.Audio = null;
                    var transcode = await _transcoder.PrepareMediaStreamSourceTranscodeAsync(_mediaStreamSource, stream, encodingProfile);

                    try
                    {
                        await transcode.TranscodeAsync();
                    }
                    catch { }
                    stream.Dispose();
                }
            }
        }

        public void Dispose()
        {
            if (_closed)
            {
                return;
            }
            _closed = true;

            if (!_isRecording)
            {
                DisposeInternal();
            }

            _isRecording = false;
        }

        private void DisposeInternal()
        {
            if (_frameGenerator != null)
            {
                _frameGenerator.Dispose();
            }
            _frameGenerator = null;
            _transcoder = null;
            _mediaStreamSource = null;
        }

        private void CreateMediaObjects()
        {
            // Create our encoding profile based on the size of the item
            int width = _captureItem.Size.Width;
            int height = _captureItem.Size.Height;

            // Describe our input: uncompressed BGRA8 buffers
            var videoProperties = VideoEncodingProperties.CreateUncompressed(MediaEncodingSubtypes.Bgra8, (uint)width, (uint)height);
            _videoDescriptor = new VideoStreamDescriptor(videoProperties);
            // Create our MediaStreamSource
            _mediaStreamSource = new MediaStreamSource(_videoDescriptor);
            _mediaStreamSource.BufferTime = TimeSpan.FromSeconds(0);
            _mediaStreamSource.Starting += OnMediaStreamSourceStarting;
            _mediaStreamSource.SampleRequested += OnMediaStreamSourceSampleRequested;

            // Create our transcoder
            _transcoder = new MediaTranscoder();
            _transcoder.HardwareAccelerationEnabled = true;
        }
        private DateTime lastFrameTime = DateTime.MinValue;
        private void OnMediaStreamSourceSampleRequested(MediaStreamSource sender, MediaStreamSourceSampleRequestedEventArgs args)
        {
            if (_isRecording && !_closed)
            {
                try
                {
                    using (var frame = _frameGenerator.WaitForNewFrame())
                    {
                        if (frame == null || !_isRecording || _closed)
                        {
                            args.Request.Sample = null;
                            DisposeInternal();
                            return;
                        }

                        var timeStamp = frame.SystemRelativeTime;
                        var sample = MediaStreamSample.CreateFromDirect3D11Surface(frame.Surface, timeStamp);

                        if ((DateTime.Now - lastFrameTime).TotalSeconds > 2.0)
                        {
                            _surface = sample.Direct3D11Surface;
                            Task.Run(async () => await Memory.Instance.OnFrame(_surface)).Wait();
                            lastFrameTime = DateTime.Now;
                        }
                        args.Request.Sample = sample;
                    }
                }
                catch (Exception e)
                {
                    Debug.WriteLine(e.Message);
                    Debug.WriteLine(e.StackTrace);
                    Debug.WriteLine(e);
                    args.Request.Sample = null;
                    DisposeInternal();
                }
            }
            else
            {
                args.Request.Sample = null;
                DisposeInternal();
            }
        }

        private void OnMediaStreamSourceStarting(MediaStreamSource sender, MediaStreamSourceStartingEventArgs args)
        {
            using (var frame = _frameGenerator.WaitForNewFrame())
            {
                if (frame == null)
                {
                    _isRecording = false;
                    Dispose();
                    return;
                }
                else
                {
                    args.Request.SetActualStartPosition(frame.SystemRelativeTime);
                }
            }
        }

        private IDirect3DSurface _surface;

        private GraphicsCaptureItem _captureItem;
        private CaptureFrameWait _frameGenerator;

        private VideoStreamDescriptor _videoDescriptor;
        public MediaStreamSource _mediaStreamSource;
        private MediaTranscoder _transcoder;
        private bool _isRecording;

        private bool _closed = false;
    }
}
