{ lib, pkgs, ... }:
{
  init = {
    azureReadyGetNetwork = {
      action = "wait";
      process = "${lib.getExe' pkgs.busybox "udhcpc"} -f -q";
    };

    azureReady = {
      tty = "console";
      action = "once";
      process = pkgs.writeScript "azureReady" (lib.fileContents ./ready.sh);
    };
  };
}
