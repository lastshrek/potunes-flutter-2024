ListTile(
  title: const Text(
    '音量标准化',
    style: TextStyle(color: Colors.white),
  ),
  subtitle: const Text(
    '自动调整所有歌曲的音量到相同水平',
    style: TextStyle(color: Colors.grey),
  ),
  trailing: Obx(() => Switch(
    value: AudioService.to.isVolumeNormalizationEnabled,
    onChanged: (value) => AudioService.to.toggleVolumeNormalization(),
    activeColor: const Color(0xFFDA5597),
  )),
), 