class HostConfig {
  final Duration turnDuration;
  final Duration moveGrace;
  final Duration reconnectWindow;
  final Duration voteDuration;
  final int chatMaxLength;
  final int maxPlayers;

  const HostConfig({
    this.turnDuration = const Duration(seconds: 45),
    this.moveGrace = const Duration(milliseconds: 500),
    this.reconnectWindow = const Duration(minutes: 2),
    this.voteDuration = const Duration(seconds: 15),
    this.chatMaxLength = 120,
    this.maxPlayers = 4,
  });
}
