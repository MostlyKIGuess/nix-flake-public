{ ... }:
{
  # Keep Brave as a focused Chromium browser: Shields and Sync stay enabled.
  programs.chromium = {
    enable = true;
    extraOpts = {
      BraveRewardsDisabled = true;
      BraveWalletDisabled = true;
      BraveVPNDisabled = true;
      BraveAIChatEnabled = false;
      BraveNewsDisabled = true;
      BraveTalkDisabled = true;
      BravePlaylistEnabled = false;

      BraveP3AEnabled = false;
      BraveStatsPingEnabled = false;
      BraveWebDiscoveryEnabled = false;
    };
  };
}
