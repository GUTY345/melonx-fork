using LibHac.Ncm;
using Ryujinx.Common;
using System.Runtime.InteropServices;
using System;

namespace Ryujinx.HLE.HOS.Services.Am.AppletAE.AllSystemAppletProxiesService.LibraryAppletProxy
{
    partial class ILibraryAppletSelfAccessor : IpcService
    {
        [DllImport("RyujinxHelper.framework/RyujinxHelper", CallingConvention = CallingConvention.Cdecl)]
        public static extern void TriggerCallback(string cIdentifier);

        private readonly AppletStandalone _appletStandalone = new();

        public ILibraryAppletSelfAccessor(ServiceCtx context)
        {
            ulong programId = context.Device.Processes.ActiveApplication.ProgramId;

            if (programId == 0x0100000000001000)
            {
                _appletStandalone = new AppletStandalone()
                {
                    AppletId = AppletId.QLaunch,
                    LibraryAppletMode = LibraryAppletMode.AllForeground,
                };

                _appletStandalone.InputData.Enqueue(Array.Empty<byte>());
            }
            else if (programId == 0x0100000000001009)
            {
                // Create MiiEdit data.
                _appletStandalone = new AppletStandalone()
                {
                    AppletId = AppletId.MiiEdit,
                    LibraryAppletMode = LibraryAppletMode.AllForeground,
                };

                byte[] miiEditInputData = new byte[0x100];
                miiEditInputData[0] = 0x03; // Hardcoded unknown value.

                _appletStandalone.InputData.Enqueue(miiEditInputData);
            }
            else
            {
                throw new NotImplementedException($"{programId} applet is not implemented.");
            }
        }

        [CommandCmif(0)]
        // PopInData() -> object<nn::am::service::IStorage>
        public ResultCode PopInData(ServiceCtx context)
        {
            if (_appletStandalone.InputData.Count == 0)
            {
                return ResultCode.NotAvailable;
            }

            byte[] appletData = _appletStandalone.InputData.Dequeue();

            if (appletData.Length == 0)
            {
                return ResultCode.NotAvailable;
            }

            MakeObject(context, new IStorage(appletData));

            return ResultCode.Success;
        }

        [CommandCmif(1)]
        public ResultCode PushOutData(ServiceCtx context)
        {
            return ResultCode.Success;
        }


        [CommandCmif(10)]
        // ExitProcessAndReturn() -> nn::am::service::ExitProcessAndReturn
        public ResultCode ExitProcessAndReturn(ServiceCtx context)
        {
            TriggerCallback("exit-emulation");
            return ResultCode.Success;
        }


        [CommandCmif(11)]
        // GetLibraryAppletInfo() -> nn::am::service::LibraryAppletInfo
        public ResultCode GetLibraryAppletInfo(ServiceCtx context)
        {
            LibraryAppletInfo libraryAppletInfo = new()
            {
                AppletId = _appletStandalone.AppletId,
                LibraryAppletMode = _appletStandalone.LibraryAppletMode,
            };

            context.ResponseData.WriteStruct(libraryAppletInfo);

            return ResultCode.Success;
        }

        [CommandCmif(12)]
        // GetMainAppletIdentityInfo() -> nn::am::service::AppletIdentityInfo
        public ResultCode GetMainAppletIdentityInfo(ServiceCtx context)
        {
            AppletIdentifyInfo appletIdentifyInfo = new()
            {
                AppletId = AppletId.QLaunch,
                TitleId = 0x0100000000001000UL,
            };

            context.ResponseData.WriteStruct(appletIdentifyInfo);

            return ResultCode.Success;
        }

        [CommandCmif(13)]
        // CanUseApplicationCore() -> bool
        public ResultCode CanUseApplicationCore(ServiceCtx context)
        {
            context.ResponseData.Write(false);

            return ResultCode.Success;
        }

        [CommandCmif(14)]
        // GetCallerAppletIdentityInfo() -> nn::am::service::AppletIdentityInfo
        public ResultCode GetCallerAppletIdentityInfo(ServiceCtx context)
        {
            AppletIdentifyInfo appletIdentifyInfo = new()
            {
                AppletId = _appletStandalone.AppletId == AppletId.QLaunch ? AppletId.Application : AppletId.QLaunch,
                TitleId = _appletStandalone.AppletId == AppletId.QLaunch ? 0UL : 0x0100000000001000UL,
            };

            context.ResponseData.WriteStruct(appletIdentifyInfo);

            return ResultCode.Success;
        }

        [CommandCmif(16)]
        // GetMainAppletStorageId() -> nn::fssrv::sf::StorageId
        public ResultCode GetMainAppletStorageId(ServiceCtx context)
        {
            context.ResponseData.Write((byte)StorageId.BuiltInSystem);

            return ResultCode.Success;
        }

        [CommandCmif(70)]
        // GetCurrentApplicationId() -> u64
        public ResultCode GetCurrentApplicationId(ServiceCtx context)
        {
            ulong titleId = context.Device.Processes.ActiveApplication.ProgramId;

            context.ResponseData.Write(titleId);

            return ResultCode.Success;
        }
    }
}
