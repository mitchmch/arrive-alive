import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../controllers/auth_controller.dart';
import '../core/access_policy.dart';
import '../core/theme.dart';
import '../models/user.dart';
import '../widgets/first_launch_guide.dart';
import '../services/profile_photo_service.dart';
import 'access_screen.dart';
import 'admin_screen.dart';
import 'history_screen.dart';
import 'login_screen.dart';
import 'scoreboard_screen.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _displayName;
  late final TextEditingController _phone;
  int? _loadedUserId;
  String? _photoPath;
  bool _removePhoto = false;
  bool _selectingPhoto = false;

  @override
  void initState() {
    super.initState();
    _displayName = TextEditingController();
    _phone = TextEditingController();
  }

  @override
  void dispose() {
    _displayName.dispose();
    _phone.dispose();
    super.dispose();
  }

  void _loadFields(AppUser user) {
    if (_loadedUserId == user.id) return;
    _loadedUserId = user.id;
    _displayName.text = user.displayName;
    _phone.text = user.phone;
    _photoPath = user.photoPath;
    _removePhoto = false;
  }

  Future<void> _selectPhoto(AppUser user) async {
    setState(() => _selectingPhoto = true);
    try {
      final path = await ProfilePhotoService().selectAndStore(user.id);
      if (mounted && path != null) {
        setState(() {
          _photoPath = path;
          _removePhoto = false;
        });
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not select that photo')),
        );
      }
    } finally {
      if (mounted) setState(() => _selectingPhoto = false);
    }
  }

  void _clearPhoto() {
    setState(() {
      _photoPath = null;
      _removePhoto = true;
    });
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final previousPhoto = ref.read(authProvider).user?.photoPath;
    final userId = ref.read(authProvider).user!.id;
    final saved = await ref.read(authProvider.notifier).updateProfile(
          displayName: _displayName.text,
          phone: _phone.text,
          photoPath: _photoPath,
          removePhoto: _removePhoto,
        );
    if (!mounted) return;
    final message = saved
        ? 'Profile saved'
        : (ref.read(authProvider).error ?? 'Could not save profile');
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
    if (saved) {
      unawaited(
        _cleanupPhotos(
          userId: userId,
          previousPhoto: previousPhoto,
          removePhoto: _removePhoto,
        ),
      );
      _removePhoto = false;
    }
  }

  Future<void> _cleanupPhotos({
    required int userId,
    required String? previousPhoto,
    required bool removePhoto,
  }) async {
    try {
      if (removePhoto) {
        await ProfilePhotoService().remove(previousPhoto);
        await ProfilePhotoService().keepOnly(userId, null);
      } else {
        await ProfilePhotoService().keepOnly(userId, _photoPath);
      }
    } catch (_) {
      // Profile persistence succeeds even if best-effort file cleanup fails.
    }
  }

  Future<void> _signOut() async {
    await ref.read(authProvider.notifier).logout();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const AccessScreen()),
      (_) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authProvider);
    final user = auth.user;
    if (!AccessPolicy.canAccessProfile(user)) {
      return _ProfileRestricted(onSignIn: () {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const LoginScreen()),
        );
      });
    }
    _loadFields(user!);

    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
            children: [
              _ProfileHeader(
                user: user,
                photoPath: _photoPath,
                selecting: _selectingPhoto,
                onSelect: () => _selectPhoto(user),
                onRemove: _photoPath == null ? null : _clearPhoto,
              ),
              const SizedBox(height: 24),
              TextFormField(
                key: const Key('profile-display-name'),
                controller: _displayName,
                textCapitalization: TextCapitalization.words,
                maxLength: 50,
                decoration: const InputDecoration(
                  labelText: 'Display name',
                  prefixIcon: Icon(Icons.badge_outlined),
                ),
                validator: (value) {
                  final length = value?.trim().length ?? 0;
                  if (length < 2) {
                    return 'Enter at least 2 characters';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                key: const Key('profile-phone'),
                controller: _phone,
                keyboardType: TextInputType.phone,
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[\d+ ()-]')),
                ],
                decoration: const InputDecoration(
                  labelText: 'Phone',
                  prefixIcon: Icon(Icons.phone_outlined),
                ),
                validator: (value) {
                  final text = value?.trim() ?? '';
                  if (user.role == 'admin' && text == user.phone) return null;
                  final digits = text.replaceAll(RegExp(r'\D'), '');
                  if (digits.length < 8 || digits.length > 15) {
                    return 'Enter a valid phone number';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 18),
              FilledButton.icon(
                key: const Key('profile-save'),
                onPressed: auth.isLoading ? null : _save,
                icon: auth.isLoading
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.check),
                label: const Text('Save changes'),
              ),
              const SizedBox(height: 28),
              Text('Explore', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              _ActionTile(
                key: const Key('profile-history'),
                icon: Icons.history,
                title: 'Journey history',
                subtitle: 'Your trips, safety scores and violations',
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const HistoryScreen()),
                ),
              ),
              _ActionTile(
                icon: Icons.menu_book_outlined,
                title: 'User Guide',
                subtitle: 'Review how to use Arrive Alive',
                onTap: () => FirstLaunchGuide.show(context),
              ),
              if (AccessPolicy.canAccessAdmin(user))
                _ActionTile(
                  key: const Key('profile-admin'),
                  icon: Icons.admin_panel_settings_outlined,
                  title: 'Admin workspace',
                  subtitle: 'Operations, moderation and sync health',
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const AdminScreen()),
                  ),
                ),
              _ActionTile(
                icon: Icons.speed_outlined,
                title: 'Speed Board',
                subtitle: 'Trusted agencies and speeding vehicles',
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const ScoreboardScreen()),
                ),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                key: const Key('profile-sign-out'),
                onPressed: _signOut,
                icon: const Icon(Icons.logout),
                label: const Text('Sign Out'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Theme.of(context).colorScheme.error,
                  side: BorderSide(color: Theme.of(context).colorScheme.error),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProfileHeader extends StatelessWidget {
  const _ProfileHeader({
    required this.user,
    required this.photoPath,
    required this.selecting,
    required this.onSelect,
    required this.onRemove,
  });

  final AppUser user;
  final String? photoPath;
  final bool selecting;
  final VoidCallback onSelect;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    final name = user.displayName.trim();
    final source = name.isEmpty ? user.phone : name;
    final words = source.split(RegExp(r'\s+')).where((word) => word.isNotEmpty);
    final initials = words.take(2).map((word) => word[0].toUpperCase()).join();
    final role = user.role == 'admin' ? 'Administrator' : 'Registered user';
    final photo = photoPath == null ? null : File(photoPath!);
    return Row(
      children: [
        Stack(
          clipBehavior: Clip.none,
          children: [
            CircleAvatar(
              key: const Key('profile-photo'),
              radius: 34,
              backgroundColor: AppTheme.primary,
              foregroundImage:
                  photo != null && photo.existsSync() ? FileImage(photo) : null,
              foregroundColor: Colors.white,
              child: photo != null && photo.existsSync()
                  ? null
                  : Text(
                      initials.isEmpty ? 'A' : initials,
                      style: Theme.of(context)
                          .textTheme
                          .titleLarge
                          ?.copyWith(color: Colors.white),
                    ),
            ),
            Positioned(
              right: -8,
              bottom: -8,
              child: IconButton.filled(
                key: const Key('profile-photo-select'),
                visualDensity: VisualDensity.compact,
                tooltip: 'Choose profile photo',
                onPressed: selecting ? null : onSelect,
                icon: selecting
                    ? const SizedBox.square(
                        dimension: 14,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.photo_library_outlined, size: 17),
              ),
            ),
          ],
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                name.isEmpty ? 'Your profile' : name,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 4),
              Text(role, style: Theme.of(context).textTheme.bodySmall),
              if (onRemove != null)
                TextButton(
                  key: const Key('profile-photo-remove'),
                  onPressed: onRemove,
                  style: TextButton.styleFrom(
                    padding: EdgeInsets.zero,
                    visualDensity: VisualDensity.compact,
                  ),
                  child: const Text('Remove photo'),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ActionTile extends StatelessWidget {
  const _ActionTile({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Icon(icon, color: AppTheme.primary),
        title: Text(title),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}

class _ProfileRestricted extends StatelessWidget {
  const _ProfileRestricted({required this.onSignIn});

  final VoidCallback onSignIn;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: Center(
        key: const Key('profile-sign-in-required'),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.lock_outline, size: 48, color: AppTheme.primary),
              const SizedBox(height: 16),
              Text(
                'Registered access required',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              const Text(
                'Sign in or create an account to manage your profile.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed: onSignIn,
                icon: const Icon(Icons.login),
                label: const Text('Sign in'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
