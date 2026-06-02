import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:potunes_flutter_2025/utils/error_reporter.dart';
import '../../services/user_service.dart';
import '../../controllers/navigation_controller.dart';
import '../../screens/pages/favourites_page.dart';
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

      // final playlists = await _networkService.getUserPlaylists();

      if (mounted) {
        setState(() {
          _playlists.clear();
          // _playlists.addAll(playlists);
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

  Future<void> _pickImage(BuildContext context) async {
    try {
      final source = await showModalBottomSheet<ImageSource>(
        context: context,
        backgroundColor: Colors.grey[900],
        builder: (context) {
          return SafeArea(
            child: Wrap(
              children: [
                ListTile(
                  leading: const Icon(Icons.photo_library, color: Colors.white),
                  title: const Text('从相册选择', style: TextStyle(color: Colors.white)),
                  onTap: () => Navigator.pop(context, ImageSource.gallery),
                ),
                ListTile(
                  leading: const Icon(Icons.photo_camera, color: Colors.white),
                  title: const Text('拍照', style: TextStyle(color: Colors.white)),
                  onTap: () => Navigator.pop(context, ImageSource.camera),
                ),
              ],
            ),
          );
        },
      );

      if (source == null) return;

      final picker = ImagePicker();
      final image = await picker.pickImage(
        source: source,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );

      if (image == null) return;

      debugPrint('ImageCropper sourcePath: ${image.path}');

      final croppedFile = await ImageCropper().cropImage(
        sourcePath: image.path,
        aspectRatio: const CropAspectRatio(ratioX: 1, ratioY: 1),
        maxWidth: 256,
        maxHeight: 256,
        compressFormat: ImageCompressFormat.jpg,
        compressQuality: 85,
        uiSettings: [
          AndroidUiSettings(
            toolbarTitle: '裁剪头像',
            toolbarColor: Colors.black,
            toolbarWidgetColor: Colors.white,
            backgroundColor: Colors.black,
            activeControlsWidgetColor: const Color(0xFFDA5597),
            cropStyle: CropStyle.rectangle,
          ),
          IOSUiSettings(
            title: '裁剪头像',
            cancelButtonTitle: '取消',
            doneButtonTitle: '完成',
          ),
        ],
      );

      debugPrint('ImageCropper result: ${croppedFile?.path}');

      if (croppedFile == null) return;
      _processCropped(croppedFile);
    } catch (e) {
      ErrorReporter.showError(e);
      if (context.mounted) {
        Get.snackbar(
          '头像更新失败',
          '打开裁剪界面时出错: $e',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Colors.black87,
          colorText: Colors.white,
          duration: const Duration(seconds: 4),
        );
      }
    }
  }

  Future<void> _processCropped(CroppedFile file) async {
    try {
      final bytes = await file.readAsBytes();
      final base64Image = 'data:image/jpeg;base64,${base64Encode(bytes)}';

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
                        (userData?['nickname']?.toString().isNotEmpty == true
                            ? userData!['nickname']
                            : _formatPhone(phone)),
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        userData?['intro']?.toString().isNotEmpty == true
                            ? userData!['intro']
                            : 'This user is too lazy to leave a signature',
                        style: TextStyle(
                          fontSize: 14,
                          color:
                              userData?['intro']?.toString().isNotEmpty == true
                                  ? Colors.grey[300]
                                  : Colors.grey[600],
                          fontStyle:
                              userData?['intro']?.toString().isNotEmpty == true
                                  ? FontStyle.normal
                                  : FontStyle.italic,
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
                      base64Decode(_avatarBase64!.contains(',')
                          ? _avatarBase64!.split(',').last
                          : _avatarBase64!),
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
                          contentPadding:
                              const EdgeInsets.symmetric(horizontal: 16.0),
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
