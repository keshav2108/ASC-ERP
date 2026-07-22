import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/auth/app_permissions.dart';
import '../../../core/theme/app_theme.dart';
import '../../auth/data/auth_provider.dart';
import '../../customers/presentation/customers_screen.dart';
import '../../dashboard/presentation/dashboard_screen.dart';
import '../../service_requests/presentation/service_requests_screen.dart';
import '../../job_cards/presentation/job_cards_screen.dart';
import '../../notifications/data/notification_navigation_provider.dart';
import '../../notifications/data/notification_provider.dart';
import '../../notifications/presentation/notification_panel.dart';
import '../../inventory/presentation/inventory_screen.dart';
import '../../invoices/presentation/invoices_screen.dart';
import '../../payments/presentation/payments_screen.dart';
import '../../technicians/presentation/technicians_screen.dart';

class AppShell extends ConsumerStatefulWidget {
  const AppShell({super.key});

  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell> {
  int selectedIndex = 0;

  static const _allMenuItems = <_MenuItem>[
    _MenuItem(
      label: 'Dashboard',
      icon: Icons.dashboard_rounded,
      page: DashboardScreen(),
      allowedRoles: AppPermissions.dashboardRoles,
    ),
    _MenuItem(
      label: 'Customers',
      icon: Icons.people_alt_rounded,
      page: CustomersScreen(),
      allowedRoles: AppPermissions.customerRoles,
    ),
    _MenuItem(
      label: 'Service Requests',
      icon: Icons.build_circle_rounded,
      page: ServiceRequestsScreen(),
      allowedRoles: AppPermissions.serviceRequestRoles,
    ),
    _MenuItem(
      label: 'Job Cards',
      icon: Icons.assignment_rounded,
      page: JobCardsScreen(),
      allowedRoles: AppPermissions.jobCardRoles,
    ),
    _MenuItem(
      label: 'Inventory',
      icon: Icons.inventory_2_rounded,
      page: InventoryScreen(),
      allowedRoles: AppPermissions.inventoryRoles,
    ),
    _MenuItem(
      label: 'Invoices',
      icon: Icons.receipt_long_rounded,
      page: InvoicesScreen(),
      allowedRoles: AppPermissions.invoiceRoles,
    ),
    _MenuItem(
      label: 'Payments',
      icon: Icons.payments_rounded,
      page: PaymentsScreen(),
      allowedRoles: AppPermissions.paymentRoles,
    ),
    _MenuItem(
      label: 'Technicians',
      icon: Icons.engineering_rounded,
      page: TechniciansScreen(),
      allowedRoles: AppPermissions.technicianRoles,
    ),
  ];

  List<_MenuItem> _menuItemsForRole(String role) {
    final normalizedRole = AppRoles.normalize(role);

    final allowedItems = _allMenuItems
        .where((item) => item.allowedRoles.contains(normalizedRole))
        .toList(growable: false);

    if (allowedItems.isNotEmpty) {
      return allowedItems;
    }

    return const [
      _MenuItem(
        label: 'No Access',
        icon: Icons.block_rounded,
        page: _NoModuleAccessPage(),
        allowedRoles: <String>{},
      ),
    ];
  }

  Future<void> _openNotifications(List<_MenuItem> menuItems) async {
    await showNotificationPanel(
      context: context,
      onOpenNotification: (notification) async {
        if (!mounted) {
          return;
        }

        final jobCardId = notification.entityId;

        if (!notification.isJobCardNotification || jobCardId == null) {
          _showShellMessage(
            'This notification is not linked to a Job Card.',
            isError: true,
          );
          return;
        }

        final jobCardsIndex = menuItems.indexWhere(
          (item) => item.label == 'Job Cards',
        );

        if (jobCardsIndex < 0) {
          _showShellMessage(
            'You do not have access to Job Cards.',
            isError: true,
          );
          return;
        }

        ref.read(pendingNotificationJobCardIdProvider.notifier).state =
            jobCardId;

        if (selectedIndex != jobCardsIndex) {
          setState(() {
            selectedIndex = jobCardsIndex;
          });
        }
      },
    );
  }

  void _showShellMessage(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: isError ? AppColors.danger : AppColors.success,
        ),
      );
  }

  Future<void> _logout() async {
    await ref.read(authProvider.notifier).logout();
  }

  void _selectMenuItem(int index, {bool closeDrawer = false}) {
    if (selectedIndex != index) {
      setState(() {
        selectedIndex = index;
      });
    }

    if (closeDrawer && Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final unreadCount = ref.watch(unreadNotificationCountProvider);
    final user = authState.user;

    final fullName = user?['full_name']?.toString() ?? 'ASC User';

    final role = user?['role']?.toString() ?? 'User';

    final menuItems = _menuItemsForRole(role);

    final activeIndex = selectedIndex >= 0 && selectedIndex < menuItems.length
        ? selectedIndex
        : 0;

    final username = user?['username']?.toString() ?? '';

    final initial = fullName.trim().isNotEmpty
        ? fullName.trim()[0].toUpperCase()
        : 'U';

    final isDesktop = MediaQuery.sizeOf(context).width >= 900;

    if (isDesktop) {
      return Scaffold(
        body: Row(
          children: [
            _buildDesktopSidebar(
              menuItems: menuItems,
              activeIndex: activeIndex,
              fullName: fullName,
              role: role,
              initial: initial,
              isLoggingOut: authState.isLoading,
            ),
            Expanded(
              child: Column(
                children: [
                  _buildTopBar(
                    menuItems: menuItems,
                    activeIndex: activeIndex,
                    fullName: fullName,
                    username: username,
                    initial: initial,
                    isLoggingOut: authState.isLoading,
                    unreadCount: unreadCount,
                  ),
                  Expanded(child: _buildSelectedPage(menuItems, activeIndex)),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(menuItems[activeIndex].label),
        actions: [
          _NotificationBellButton(
            unreadCount: unreadCount,
            onPressed: () {
              _openNotifications(menuItems);
            },
          ),
          IconButton(
            tooltip: 'Logout',
            onPressed: authState.isLoading ? null : _logout,
            icon: const Icon(Icons.logout_rounded, color: AppColors.danger),
          ),
          const SizedBox(width: 8),
        ],
      ),
      drawer: Drawer(
        backgroundColor: AppColors.sidebar,
        child: _buildSidebarContent(
          menuItems: menuItems,
          activeIndex: activeIndex,
          fullName: fullName,
          role: role,
          initial: initial,
          isLoggingOut: authState.isLoading,
          closeDrawerAfterSelection: true,
        ),
      ),
      body: _buildSelectedPage(menuItems, activeIndex),
    );
  }

  Widget _buildSelectedPage(List<_MenuItem> menuItems, int activeIndex) {
    return IndexedStack(
      index: activeIndex,
      children: menuItems.map((item) => item.page).toList(growable: false),
    );
  }

  Widget _buildDesktopSidebar({
    required List<_MenuItem> menuItems,
    required int activeIndex,
    required String fullName,
    required String role,
    required String initial,
    required bool isLoggingOut,
  }) {
    return Container(
      width: 260,
      color: AppColors.sidebar,
      child: _buildSidebarContent(
        menuItems: menuItems,
        activeIndex: activeIndex,
        fullName: fullName,
        role: role,
        initial: initial,
        isLoggingOut: isLoggingOut,
        closeDrawerAfterSelection: false,
      ),
    );
  }

  Widget _buildSidebarContent({
    required List<_MenuItem> menuItems,
    required int activeIndex,
    required String fullName,
    required String role,
    required String initial,
    required bool isLoggingOut,
    required bool closeDrawerAfterSelection,
  }) {
    return SafeArea(
      child: Column(
        children: [
          const Padding(
            padding: EdgeInsets.all(24),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 21,
                  backgroundColor: AppColors.primary,
                  child: Icon(
                    Icons.settings_suggest_rounded,
                    color: Colors.white,
                  ),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'ASC Manager',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 19,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              itemCount: menuItems.length,
              separatorBuilder: (context, index) {
                return const SizedBox(height: 6);
              },
              itemBuilder: (context, index) {
                final item = menuItems[index];

                return _SidebarMenuButton(
                  item: item,
                  isSelected: activeIndex == index,
                  onTap: () {
                    _selectMenuItem(
                      index,
                      closeDrawer: closeDrawerAfterSelection,
                    );
                  },
                );
              },
            ),
          ),
          const Divider(height: 1, color: Color(0xFF374151)),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Row(
              children: [
                CircleAvatar(
                  backgroundColor: AppColors.primary,
                  child: Text(
                    initial,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        fullName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        role.toUpperCase(),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Color(0xFF9CA3AF),
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 14),
            child: _LogoutButton(isLoggingOut: isLoggingOut, onTap: _logout),
          ),
        ],
      ),
    );
  }

  Widget _buildTopBar({
    required List<_MenuItem> menuItems,
    required int activeIndex,
    required String fullName,
    required String username,
    required String initial,
    required bool isLoggingOut,
    required int unreadCount,
  }) {
    return Container(
      height: 74,
      padding: const EdgeInsets.symmetric(horizontal: 28),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        children: [
          Text(
            menuItems[activeIndex].label,
            style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w700),
          ),
          const Spacer(),
          SizedBox(
            width: 280,
            child: TextField(
              decoration: const InputDecoration(
                hintText: 'Search...',
                prefixIcon: Icon(Icons.search_rounded),
              ),
            ),
          ),
          const SizedBox(width: 16),
          _NotificationBellButton(
            unreadCount: unreadCount,
            onPressed: () {
              _openNotifications(menuItems);
            },
          ),
          const SizedBox(width: 4),
          IconButton(
            tooltip: 'Logout',
            onPressed: isLoggingOut ? null : _logout,
            icon: const Icon(Icons.logout_rounded, color: AppColors.danger),
          ),
          const SizedBox(width: 12),
          CircleAvatar(
            backgroundColor: AppColors.primary,
            child: Text(
              initial,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                fullName,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              if (username.isNotEmpty)
                Text(
                  '@$username',
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SidebarMenuButton extends StatefulWidget {
  const _SidebarMenuButton({
    required this.item,
    required this.isSelected,
    required this.onTap,
  });

  final _MenuItem item;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  State<_SidebarMenuButton> createState() => _SidebarMenuButtonState();
}

class _SidebarMenuButtonState extends State<_SidebarMenuButton> {
  bool _isHovered = false;
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final isSelected = widget.isSelected;

    final backgroundColor = isSelected
        ? AppColors.sidebarSelected
        : _isHovered
        ? const Color(0xFF263548)
        : Colors.transparent;

    final foregroundColor = isSelected || _isHovered
        ? Colors.white
        : const Color(0xFFD1D5DB);

    final iconColor = isSelected || _isHovered
        ? Colors.white
        : const Color(0xFF9CA3AF);

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (event) {
        if (!_isHovered) {
          setState(() {
            _isHovered = true;
          });
        }
      },
      onExit: (event) {
        if (_isHovered || _isPressed) {
          setState(() {
            _isHovered = false;
            _isPressed = false;
          });
        }
      },
      child: AnimatedSlide(
        duration: const Duration(milliseconds: 130),
        curve: Curves.easeOutCubic,
        offset: _isHovered && !isSelected
            ? const Offset(0.018, 0)
            : Offset.zero,
        child: AnimatedScale(
          duration: const Duration(milliseconds: 90),
          curve: Curves.easeOut,
          scale: _isPressed ? 0.985 : 1,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            curve: Curves.easeOutCubic,
            decoration: BoxDecoration(
              color: backgroundColor,
              borderRadius: BorderRadius.circular(12),
              border: Border(
                left: BorderSide(
                  color: isSelected ? AppColors.primary : Colors.transparent,
                  width: 3,
                ),
              ),
              boxShadow: _isHovered && !isSelected
                  ? [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.18),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ]
                  : const [],
            ),
            child: Material(
              color: Colors.transparent,
              borderRadius: BorderRadius.circular(12),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                mouseCursor: SystemMouseCursors.click,
                borderRadius: BorderRadius.circular(12),
                splashColor: AppColors.primary.withValues(alpha: 0.24),
                highlightColor: Colors.white.withValues(alpha: 0.06),
                hoverColor: Colors.transparent,
                onHighlightChanged: (pressed) {
                  if (_isPressed != pressed) {
                    setState(() {
                      _isPressed = pressed;
                    });
                  }
                },
                onTap: widget.onTap,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 15,
                    vertical: 13,
                  ),
                  child: Row(
                    children: [
                      AnimatedScale(
                        duration: const Duration(milliseconds: 130),
                        curve: Curves.easeOutBack,
                        scale: isSelected || _isHovered ? 1.10 : 1,
                        child: Icon(widget.item.icon, color: iconColor),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: AnimatedDefaultTextStyle(
                          duration: const Duration(milliseconds: 130),
                          curve: Curves.easeOutCubic,
                          style: TextStyle(
                            color: foregroundColor,
                            fontWeight: isSelected
                                ? FontWeight.w700
                                : _isHovered
                                ? FontWeight.w600
                                : FontWeight.w500,
                          ),
                          child: Text(widget.item.label),
                        ),
                      ),
                      AnimatedOpacity(
                        duration: const Duration(milliseconds: 130),
                        opacity: isSelected ? 1 : 0,
                        child: const Icon(
                          Icons.chevron_right_rounded,
                          color: Colors.white,
                          size: 19,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _NotificationBellButton extends StatelessWidget {
  const _NotificationBellButton({
    required this.unreadCount,
    required this.onPressed,
  });

  final int unreadCount;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final hasUnread = unreadCount > 0;
    final badgeText = unreadCount > 99 ? '99+' : unreadCount.toString();

    return IconButton(
      tooltip: hasUnread
          ? 'Notifications ($unreadCount unread)'
          : 'Notifications',
      onPressed: onPressed,
      icon: Stack(
        clipBehavior: Clip.none,
        children: [
          Icon(
            hasUnread
                ? Icons.notifications_rounded
                : Icons.notifications_none_rounded,
          ),
          if (hasUnread)
            Positioned(
              top: -9,
              right: -11,
              child: Container(
                constraints: const BoxConstraints(minWidth: 19, minHeight: 19),
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.danger,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppColors.surface, width: 2),
                ),
                child: Text(
                  badgeText,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                    height: 1,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _LogoutButton extends StatefulWidget {
  const _LogoutButton({required this.isLoggingOut, required this.onTap});

  final bool isLoggingOut;
  final VoidCallback onTap;

  @override
  State<_LogoutButton> createState() => _LogoutButtonState();
}

class _LogoutButtonState extends State<_LogoutButton> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: widget.isLoggingOut
          ? SystemMouseCursors.basic
          : SystemMouseCursors.click,
      onEnter: (event) {
        if (!widget.isLoggingOut) {
          setState(() {
            _isHovered = true;
          });
        }
      },
      onExit: (event) {
        if (_isHovered) {
          setState(() {
            _isHovered = false;
          });
        }
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        curve: Curves.easeOutCubic,
        decoration: BoxDecoration(
          color: _isHovered ? const Color(0xFF452B35) : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            splashColor: AppColors.danger.withValues(alpha: 0.22),
            onTap: widget.isLoggingOut ? null : widget.onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
              child: Row(
                children: [
                  if (widget.isLoggingOut)
                    const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Color(0xFFFCA5A5),
                      ),
                    )
                  else
                    const Icon(Icons.logout_rounded, color: Color(0xFFFCA5A5)),
                  const SizedBox(width: 16),
                  Text(
                    widget.isLoggingOut ? 'Signing out...' : 'Logout',
                    style: const TextStyle(
                      color: Color(0xFFFCA5A5),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _NoModuleAccessPage extends StatelessWidget {
  const _NoModuleAccessPage();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.lock_outline_rounded,
              size: 56,
              color: AppColors.textSecondary,
            ),
            SizedBox(height: 16),
            Text(
              'No modules are available for this role.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
          ],
        ),
      ),
    );
  }
}

class _MenuItem {
  const _MenuItem({
    required this.label,
    required this.icon,
    required this.page,
    required this.allowedRoles,
  });

  final String label;
  final IconData icon;
  final Widget page;
  final Set<String> allowedRoles;
}
