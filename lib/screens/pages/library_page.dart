import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import 'package:potunes_flutter_2025/utils/error_reporter.dart';
import '../../services/user_service.dart';
import 'dart:convert';
import 'dart:io';
import '../../controllers/navigation_controller.dart';
import '../../screens/pages/favourites_page.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import '../../screens/pages/profile_page.dart';
import '../../widgets/common/app_header.dart';
import '../../widgets/common/app_drawer.dart';
import '../../services/network_service.dart';
import '../../screens/pages/playlist_detail_page.dart';

class LibraryPage extends StatefulWidget {
  const LibraryPage({super.key});

  @override
  State<LibraryPage> createState() => _LibraryPageState();
}

class _LibraryPageState extends State<LibraryPage> {
  String? _avatarBase64;
  final _userData = Rx<Map<String, dynamic>?>(null);
  final NetworkService _networkService = NetworkService.instance;
  final List<Map<String, dynamic>> _playlists = [];
  bool _isLoadingPlaylists = false;

  @override
  void initState() {
    super.initState();
    _avatarBase64 = UserService.to.userData?['avatar'];
    _userData.value = UserService.to.userData;
    _loadPlaylists();
  }

  Future<void> _loadPlaylists() async {
    try {
      setState(() {
        _isLoadingPlaylists = true;
      });

      final playlists = await _networkService.getUserPlaylists();

      if (mounted) {
        setState(() {
          _playlists.clear();
          _playlists.addAll(playlists);
          _isLoadingPlaylists = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingPlaylists = false;
        });
      }
    }
  }

  void _refreshUserData() {
    setState(() {
      _userData.value = UserService.to.userData;
      _avatarBase64 = _userData.value?['avatar'];
    });
  }

  String _formatPhone(String phone) {
    if (phone.isEmpty) return '';
    if (phone.length != 11) return phone;
    // 保留前3位和后4位，中间4位用星号代替
    return '${phone.substring(0, 3)}****${phone.substring(7, 11)}';
  }

  // 选择图片
  Future<void> _pickImage(BuildContext context) async {
    try {
      final ImagePicker picker = ImagePicker();

      // 显示选择对话框
      await showModalBottomSheet(
        context: context,
        backgroundColor: Colors.grey[900],
        builder: (BuildContext context) {
          return SafeArea(
            child: Wrap(
              children: <Widget>[
                ListTile(
                  leading: const Icon(Icons.photo_library, color: Colors.white),
                  title: const Text(
                    'Choose from Gallery',
                    style: TextStyle(color: Colors.white),
                  ),
                  onTap: () async {
                    Navigator.pop(context);
                    final XFile? image = await picker.pickImage(
                      source: ImageSource.gallery,
                      maxWidth: 1024,
                      maxHeight: 1024,
                      imageQuality: 85,
                    );
                    if (image != null) {
                      _processImage(image);
                    }
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.photo_camera, color: Colors.white),
                  title: const Text(
                    'Take a Photo',
                    style: TextStyle(color: Colors.white),
                  ),
                  onTap: () async {
                    Navigator.pop(context);
                    final XFile? image = await picker.pickImage(
                      source: ImageSource.camera,
                      maxWidth: 1024,
                      maxHeight: 1024,
                      imageQuality: 85,
                    );
                    if (image != null) {
                      _processImage(image);
                    }
                  },
                ),
              ],
            ),
          );
        },
      );
    } catch (e) {
      print('Error picking image: $e');
    }
  }

  // 处理并上传图片
  Future<void> _processImage(XFile image) async {
    try {
      final File imageFile = File(image.path);

      // 进一步降低压缩参数
      final List<int> compressedBytes = await FlutterImageCompress.compressWithFile(
            imageFile.absolute.path,
            minWidth: 256, // 降低最大宽度
            minHeight: 256, // 降低最大高度
            quality: 50, // 降低压缩质量
          ) ??
          [];

      if (compressedBytes.isEmpty) {
        throw '图片压缩失败';
      }

      // 检查压缩后的大小
      final int sizeInKB = compressedBytes.length ~/ 1024;

      // 如果还是太大，进一步压缩
      if (sizeInKB > 100) {
        final List<int> furtherCompressedBytes = await FlutterImageCompress.compressWithFile(
              imageFile.absolute.path,
              minWidth: 128,
              minHeight: 128,
              quality: 30,
            ) ??
            [];

        if (furtherCompressedBytes.isNotEmpty) {
          compressedBytes.clear();
          compressedBytes.addAll(furtherCompressedBytes);
        }
      }

      // 转换为 base64
      final String base64Image = 'data:image/jpeg;base64,${base64Encode(compressedBytes)}';

      setState(() {
        _avatarBase64 = base64Image;
      });

      await UserService.to.updateAvatar(base64Image);
    } catch (e) {
      ErrorReporter.showError(e);
    }
  }

  void _navigateToPage(Widget page) async {
    final result = await Get.to(
      () => page,
      transition: Transition.rightToLeft,
      duration: const Duration(milliseconds: 300),
    );

    if (result != null && result is Map<String, dynamic>) {
      _refreshUserData();
    }
  }

  // 用户信息区域
  Widget _buildProfileSection(String phone, Map<String, dynamic>? userData) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16.0, 0, 16.0, 16.0),
      decoration: BoxDecoration(
        color: Colors.grey[900]?.withOpacity(0.5),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          // 头像和基本信息
          Padding(
            padding: const EdgeInsets.fromLTRB(20.0, 20.0, 20.0, 20.0),
            child: Row(
              children: [
                _buildAvatarWidget(),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        (userData?['nickname']?.toString().isNotEmpty == true ? userData!['nickname'] : _formatPhone(phone)),
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        userData?['intro']?.toString().isNotEmpty == true ? userData!['intro'] : 'This user is too lazy to leave a signature',
                        style: TextStyle(
                          fontSize: 14,
                          color: userData?['intro']?.toString().isNotEmpty == true ? Colors.grey[300] : Colors.grey[600],
                          fontStyle: userData?['intro']?.toString().isNotEmpty == true ? FontStyle.normal : FontStyle.italic,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          // 功能按钮
          Padding(
            padding: const EdgeInsets.fromLTRB(12.0, 0, 12.0, 12.0),
            child: Row(
              children: [
                Expanded(
                  child: _buildActionButton(
                    icon: Icons.favorite,
                    iconColor: const Color(0xFFDA5597),
                    label: 'Favourites',
                    onTap: () => _navigateToPage(const FavouritesPage()),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildActionButton(
                    icon: Icons.edit,
                    iconColor: Colors.white,
                    label: 'Edit Profile',
                    onTap: () => _navigateToPage(const ProfilePage()),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required Color iconColor,
    required String label,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.2),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                color: iconColor,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAvatarWidget() {
    return Stack(
      children: [
        GestureDetector(
          onTap: () => _pickImage(context),
          child: Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.3),
                  blurRadius: 15,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: _avatarBase64 != null
                ? CircleAvatar(
                    radius: 40, // 减小头像尺寸
                    backgroundImage: MemoryImage(
                      base64Decode(_avatarBase64!.contains(',') ? _avatarBase64!.split(',').last : _avatarBase64!),
                    ),
                  )
                : const CircleAvatar(
                    radius: 40, // 减小头像尺寸
                    backgroundColor: Color(0xFF1E1E1E),
                    child: Icon(
                      Icons.person,
                      size: 40, // 减小图标尺寸
                      color: Colors.white70,
                    ),
                  ),
          ),
        ),
        // 编辑图标
        Positioned(
          right: 0,
          bottom: 0,
          child: Container(
            padding: const EdgeInsets.all(6), // 减小编辑按钮尺寸
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.2),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: GestureDetector(
              onTap: () => _pickImage(context),
              child: const Icon(
                Icons.edit,
                size: 14, // 减小图标尺寸
                color: Color(0xFFDA5597),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _deletePlaylist(Map<String, dynamic> playlist) async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: Colors.grey[900],
          title: const Text(
            'Delete Playlist',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          content: Text(
            'Are you sure you want to delete "${playlist['title']}"?',
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 16,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text(
                'Cancel',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 16,
                ),
              ),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: TextButton.styleFrom(
                backgroundColor: Colors.red[400],
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text(
                'Delete',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        );
      },
    );

    if (confirm == true) {
      try {
        // TODO: 实现删除歌单的网络请求
        // await _networkService.deletePlaylist(playlist['id']);
        setState(() {
          _playlists.removeWhere((item) => item['id'] == playlist['id']);
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Playlist deleted')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Failed to delete playlist')),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final userData = _userData.value;
    final phone = userData?['phone']?.toString() ?? '';

    return Scaffold(
      backgroundColor: Colors.black,
      drawer: const AppDrawer(),
      body: CustomScrollView(
        slivers: [
          const AppHeader(title: 'Library'),

          // 个人资料区域（包含 Favourites 和 Edit Profile）
          SliverToBoxAdapter(
            child: _buildProfileSection(phone, userData),
          ),

          // 歌单列表
          SliverToBoxAdapter(
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 16.0),
              decoration: BoxDecoration(
                color: Colors.grey[900]?.withOpacity(0.5),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.2),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const ListTile(
                    contentPadding: EdgeInsets.symmetric(horizontal: 16.0),
                    leading: Icon(
                      Icons.playlist_play,
                      color: Colors.white,
                    ),
                    title: Text(
                      'My Playlists',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  if (_isLoadingPlaylists)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 16.0),
                      child: Center(
                        child: CircularProgressIndicator(),
                      ),
                    )
                  else if (_playlists.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 16.0),
                      child: Center(
                        child: Text(
                          'No playlists yet',
                          style: TextStyle(
                            color: Colors.grey,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    )
                  else
                    ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      padding: EdgeInsets.zero,
                      itemCount: _playlists.length,
                      itemBuilder: (context, index) {
                        final playlist = _playlists[index];
                        return ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16.0),
                          leading: Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: Colors.grey[850],
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(
                              Icons.queue_music,
                              color: Colors.white,
                              size: 20,
                            ),
                          ),
                          title: Text(
                            playlist['title'] ?? '',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                            ),
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(
                                  Icons.more_vert,
                                  color: Colors.grey,
                                  size: 20,
                                ),
                                onPressed: () {
                                  showModalBottomSheet(
                                    context: context,
                                    backgroundColor: Colors.grey[900],
                                    builder: (context) => SafeArea(
                                      child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          ListTile(
                                            leading: const Icon(
                                              Icons.delete_outline,
                                              color: Colors.red,
                                            ),
                                            title: const Text(
                                              'Delete Playlist',
                                              style: TextStyle(
                                                color: Colors.white,
                                                fontSize: 16,
                                              ),
                                            ),
                                            onTap: () {
                                              Navigator.pop(context);
                                              _deletePlaylist(playlist);
                                            },
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ],
                          ),
                          onTap: () {
                            Get.to(
                              () => PlaylistDetailPage(
                                playlistId: playlist['id'],
                                title: playlist['title'] ?? '',
                              ),
                              transition: Transition.rightToLeft,
                            );
                          },
                        );
                      },
                    ),
                ],
              ),
            ),
          ),

          // 底部空间和退出登录按钮
          SliverFillRemaining(
            hasScrollBody: false,
            child: Container(
              padding: const EdgeInsets.all(16.0),
              alignment: Alignment.bottomCenter,
              child: TextButton(
                onPressed: () async {
                  // 显示确认对话框
                  final bool? confirm = await showDialog<bool>(
                    context: context,
                    builder: (BuildContext context) {
                      return AlertDialog(
                        backgroundColor: Colors.grey[900],
                        title: const Text(
                          'Confirm Logout',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        content: const Text(
                          'Are you sure you want to logout?',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 16,
                          ),
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.of(context).pop(false),
                            child: const Text(
                              'Cancel',
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 16,
                              ),
                            ),
                          ),
                          TextButton(
                            onPressed: () => Navigator.of(context).pop(true),
                            style: TextButton.styleFrom(
                              backgroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            child: const Text(
                              'Logout',
                              style: TextStyle(
                                color: Colors.black,
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      );
                    },
                  );

                  // 如果用户确认登出
                  if (confirm == true) {
                    try {
                      await UserService.to.logout();
                      NavigationController.to.changePage(0);
                      Get.snackbar(
                        'Success',
                        'Logged out successfully',
                        snackPosition: SnackPosition.BOTTOM,
                        backgroundColor: Colors.green,
                        colorText: Colors.white,
                        margin: const EdgeInsets.all(16),
                      );
                    } catch (e) {
                      print('Error during logout: $e');
                      Get.snackbar(
                        'Error',
                        'Failed to logout',
                        snackPosition: SnackPosition.BOTTOM,
                        backgroundColor: Colors.red,
                        colorText: Colors.white,
                        margin: const EdgeInsets.all(16),
                      );
                    }
                  }
                },
                style: TextButton.styleFrom(
                  backgroundColor: Colors.white,
                  minimumSize: const Size(double.infinity, 48),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const Text(
                  'Logout',
                  style: TextStyle(
                    color: Colors.black,
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
