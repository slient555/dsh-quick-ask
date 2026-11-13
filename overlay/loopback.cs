using System;
using System.Collections.Generic;
using System.IO;
using System.Runtime.InteropServices;
using System.Threading;

namespace QaAudio
{
    [ComImport, Guid("BCDE0395-E52F-467C-8E3D-C4579291692E")]
    internal class MMDeviceEnumeratorComObject { }

    internal enum EDataFlow { eRender = 0, eCapture = 1, eAll = 2 }
    internal enum ERole { eConsole = 0, eMultimedia = 1, eCommunications = 2 }

    [ComImport, Guid("A95664D2-9614-4F35-A746-DE8DB63617E6"), InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
    internal interface IMMDeviceEnumerator
    {
        int EnumAudioEndpoints(EDataFlow dataFlow, int stateMask, out IntPtr devices);
        int GetDefaultAudioEndpoint(EDataFlow dataFlow, ERole role, out IMMDevice endpoint);
        int GetDevice([MarshalAs(UnmanagedType.LPWStr)] string id, out IMMDevice device);
    }

    [ComImport, Guid("D666063F-1587-4E43-81F1-B948E807363F"), InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
    internal interface IMMDevice
    {
        int Activate(ref Guid iid, int clsCtx, IntPtr activationParams, [MarshalAs(UnmanagedType.IUnknown)] out object interfacePtr);
        int OpenPropertyStore(int stgmAccess, out IntPtr properties);
        int GetId([MarshalAs(UnmanagedType.LPWStr)] out string id);
        int GetState(out int state);
    }

    [ComImport, Guid("1CB9AD4C-DBFA-4c32-B178-C2F568A703B2"), InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
    internal interface IAudioClient
    {
        int Initialize(int shareMode, int streamFlags, long hnsBufferDuration, long hnsPeriodicity, IntPtr format, IntPtr audioSessionGuid);
        int GetBufferSize(out uint bufferFrames);
        int GetStreamLatency(out long latency);
        int GetCurrentPadding(out uint padding);
        int IsFormatSupported(int shareMode, IntPtr format, out IntPtr closestMatch);
        int GetMixFormat(out IntPtr deviceFormat);
        int GetDevicePeriod(out long defaultPeriod, out long minPeriod);
        int Start();
        int Stop();
        int Reset();
        int SetEventHandle(IntPtr eventHandle);
        int GetService(ref Guid iid, [MarshalAs(UnmanagedType.IUnknown)] out object service);
    }

    [ComImport, Guid("C8ADBD64-E71E-48a0-A4DE-185C395CD317"), InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
    internal interface IAudioCaptureClient
    {
        int GetBuffer(out IntPtr data, out uint frames, out int flags, out long devicePosition, out long qpcPosition);
        int ReleaseBuffer(uint frames);
        int GetNextPacketSize(out uint frames);
    }

    [StructLayout(LayoutKind.Sequential, Pack = 2)]
    internal struct WAVEFORMATEX
    {
        public ushort wFormatTag;
        public ushort nChannels;
        public uint nSamplesPerSec;
        public uint nAvgBytesPerSec;
        public ushort nBlockAlign;
        public ushort wBitsPerSample;
        public ushort cbSize;
    }

    /// <summary>把系统正在播放的声音（对方说话）录成 16k/单声道/16bit 的 WAV。</summary>
    public static class Loopback
    {
        const int AUDCLNT_SHAREMODE_SHARED = 0;
        const int AUDCLNT_STREAMFLAGS_LOOPBACK = 2;

        public static string LastError = "";

        public static void RecordWav(string path, int seconds)
        {
            LastError = "";
            var enumerator = (IMMDeviceEnumerator)new MMDeviceEnumeratorComObject();
            IMMDevice device;
            enumerator.GetDefaultAudioEndpoint(EDataFlow.eRender, ERole.eCommunications, out device);
            if (device == null) enumerator.GetDefaultAudioEndpoint(EDataFlow.eRender, ERole.eConsole, out device);
            if (device == null) throw new Exception("找不到默认播放设备");

            Guid iid = typeof(IAudioClient).GUID;
            object clientObj;
            int hr = device.Activate(ref iid, 23, IntPtr.Zero, out clientObj);
            if (hr != 0) throw new COMException("Activate", hr);
            var client = (IAudioClient)clientObj;

            IntPtr mixPtr;
            hr = client.GetMixFormat(out mixPtr);
            if (hr != 0) throw new COMException("GetMixFormat", hr);
            var mix = (WAVEFORMATEX)Marshal.PtrToStructure(mixPtr, typeof(WAVEFORMATEX));
            int channels = mix.nChannels;
            int rate = (int)mix.nSamplesPerSec;
            int bits = mix.wBitsPerSample;

            hr = client.Initialize(AUDCLNT_SHAREMODE_SHARED, AUDCLNT_STREAMFLAGS_LOOPBACK, 10000000L, 0, mixPtr, IntPtr.Zero);
            if (hr != 0) throw new COMException("Initialize(loopback)", hr);

            Guid capIid = typeof(IAudioCaptureClient).GUID;
            object capObj;
            hr = client.GetService(ref capIid, out capObj);
            if (hr != 0) throw new COMException("GetService", hr);
            var capture = (IAudioCaptureClient)capObj;

            var pcm = new MemoryStream();
            client.Start();
            var deadline = DateTime.UtcNow.AddSeconds(seconds);
            while (DateTime.UtcNow < deadline)
            {
                uint packet;
                if (capture.GetNextPacketSize(out packet) != 0) break;
                while (packet > 0)
                {
                    IntPtr data;
                    uint frames;
                    int flags;
                    long pos, qpc;
                    if (capture.GetBuffer(out data, out frames, out flags, out pos, out qpc) != 0) break;
                    int block = (bits / 8) * channels;
                    int bytes = (int)frames * block;
                    if (frames > 0 && bytes > 0)
                    {
                        byte[] buf = new byte[bytes];
                        Marshal.Copy(data, buf, 0, bytes);
                        pcm.Write(buf, 0, bytes);
                    }
                    capture.ReleaseBuffer(frames);
                    if (capture.GetNextPacketSize(out packet) != 0) break;
                }
                Thread.Sleep(10);
            }
            client.Stop();

            byte[] raw = pcm.ToArray();
            short[] mono16k = ToMono16k(raw, channels, rate, bits);

            using (var fs = new FileStream(path, FileMode.Create, FileAccess.Write))
            using (var bw = new BinaryWriter(fs))
            {
                bw.Write(new[] { 'R', 'I', 'F', 'F' });
                bw.Write(36 + mono16k.Length * 2);
                bw.Write(new[] { 'W', 'A', 'V', 'E' });
                bw.Write(new[] { 'f', 'm', 't', ' ' });
                bw.Write(16);
                bw.Write((ushort)1);
                bw.Write((ushort)1);
                bw.Write(16000);
                bw.Write(32000);
                bw.Write((ushort)2);
                bw.Write((ushort)16);
                bw.Write(new[] { 'd', 'a', 't', 'a' });
                bw.Write(mono16k.Length * 2);
                foreach (short s in mono16k) bw.Write(s);
            }
        }

        static short[] ToMono16k(byte[] raw, int channels, int rate, int bits)
        {
            int bytesPerSample = bits / 8;
            int frames = raw.Length / (bytesPerSample * channels);
            float[] mono = new float[frames];
            for (int i = 0; i < frames; i++)
            {
                float acc = 0;
                for (int c = 0; c < channels; c++)
                {
                    int off = (i * channels + c) * bytesPerSample;
                    if (bits == 32) acc += BitConverter.ToSingle(raw, off);
                    else if (bits == 16) acc += BitConverter.ToInt16(raw, off) / 32768f;
                    else acc += 0;
                }
                mono[i] = acc / Math.Max(1, channels);
            }

            int outCount = (int)((long)frames * 16000 / Math.Max(1, rate));
            var outp = new short[outCount];
            double step = (double)rate / 16000.0;
            for (int i = 0; i < outCount; i++)
            {
                double srcPos = i * step;
                int idx = (int)srcPos;
                if (idx >= frames) idx = frames - 1;
                float v = idx >= 0 && frames > 0 ? mono[idx] : 0f;
                if (v > 1f) v = 1f;
                if (v < -1f) v = -1f;
                outp[i] = (short)(v * 32767);
            }
            return outp;
        }
    }
}
