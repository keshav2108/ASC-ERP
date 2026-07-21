class AppRoles {
  AppRoles._();

  static const String admin = 'ADMIN';
  static const String serviceManager = 'SERVICE_MANAGER';
  static const String serviceExecutive = 'SERVICE_EXECUTIVE';
  static const String technician = 'TECHNICIAN';
  static const String accountant = 'ACCOUNTANT';

  static String normalize(Object? role) {
    return role
            ?.toString()
            .trim()
            .toUpperCase()
            .replaceAll('-', '_')
            .replaceAll(' ', '_') ??
        '';
  }

  static String fromUser(Map<String, dynamic>? user) {
    return normalize(user?['role']);
  }
}

class AppPermissions {
  AppPermissions._();

  static const Set<String> dashboardRoles = {
    AppRoles.admin,
    AppRoles.serviceManager,
    AppRoles.accountant,
  };

  static const Set<String> customerRoles = {
    AppRoles.admin,
    AppRoles.serviceManager,
    AppRoles.serviceExecutive,
  };

  static const Set<String> serviceRequestRoles = {
    AppRoles.admin,
    AppRoles.serviceManager,
    AppRoles.serviceExecutive,
  };

  static const Set<String> jobCardRoles = {
    AppRoles.admin,
    AppRoles.serviceManager,
    AppRoles.serviceExecutive,
    AppRoles.technician,
  };

  static const Set<String> inventoryRoles = {
    AppRoles.admin,
    AppRoles.serviceManager,
    AppRoles.accountant,
  };

  static const Set<String> invoiceRoles = {AppRoles.admin, AppRoles.accountant};

  static const Set<String> paymentRoles = {AppRoles.admin, AppRoles.accountant};

  static const Set<String> technicianRoles = {
    AppRoles.admin,
    AppRoles.serviceManager,
    AppRoles.technician,
  };

  static bool hasAnyRole(Object? role, Set<String> allowedRoles) {
    return allowedRoles.contains(AppRoles.normalize(role));
  }

  static bool isAdmin(Object? role) {
    return AppRoles.normalize(role) == AppRoles.admin;
  }

  static bool isServiceManager(Object? role) {
    return AppRoles.normalize(role) == AppRoles.serviceManager;
  }

  static bool isServiceExecutive(Object? role) {
    return AppRoles.normalize(role) == AppRoles.serviceExecutive;
  }

  static bool isTechnician(Object? role) {
    return AppRoles.normalize(role) == AppRoles.technician;
  }

  static bool isAccountant(Object? role) {
    return AppRoles.normalize(role) == AppRoles.accountant;
  }

  static bool canViewDashboard(Object? role) {
    return hasAnyRole(role, dashboardRoles);
  }

  static bool canViewCustomers(Object? role) {
    return hasAnyRole(role, customerRoles);
  }

  static bool canCreateCustomer(Object? role) {
    return canViewCustomers(role);
  }

  static bool canEditCustomer(Object? role) {
    return canViewCustomers(role);
  }

  static bool canViewServiceRequests(Object? role) {
    return hasAnyRole(role, serviceRequestRoles);
  }

  static bool canCreateServiceRequest(Object? role) {
    return canViewServiceRequests(role);
  }

  static bool canEditServiceRequest(Object? role) {
    return canViewServiceRequests(role);
  }

  static bool canManageServiceRequests(Object? role) {
    final normalizedRole = AppRoles.normalize(role);

    return normalizedRole == AppRoles.admin ||
        normalizedRole == AppRoles.serviceManager;
  }

  static bool canAssignTechnician(Object? role) {
    return canManageServiceRequests(role);
  }

  static bool canCancelServiceRequest(Object? role) {
    return canManageServiceRequests(role);
  }

  static bool canViewJobCards(Object? role) {
    return hasAnyRole(role, jobCardRoles);
  }

  static bool canManageJobCards(Object? role) {
    final normalizedRole = AppRoles.normalize(role);

    return normalizedRole == AppRoles.admin ||
        normalizedRole == AppRoles.serviceManager;
  }

  static bool canEditJobCards(Object? role) {
    return canManageJobCards(role);
  }

  static bool canRunJobCardWorkflow(Object? role) {
    final normalizedRole = AppRoles.normalize(role);

    return normalizedRole == AppRoles.admin ||
        normalizedRole == AppRoles.serviceManager ||
        normalizedRole == AppRoles.technician;
  }

  static bool canCompleteDelivery(Object? role) {
    return canManageJobCards(role);
  }

  static bool canViewInventory(Object? role) {
    return hasAnyRole(role, inventoryRoles);
  }

  static bool canManageInventory(Object? role) {
    final normalizedRole = AppRoles.normalize(role);

    return normalizedRole == AppRoles.admin ||
        normalizedRole == AppRoles.serviceManager;
  }

  static bool canViewInvoices(Object? role) {
    return hasAnyRole(role, invoiceRoles);
  }

  static bool canManageInvoices(Object? role) {
    final normalizedRole = AppRoles.normalize(role);

    return normalizedRole == AppRoles.admin ||
        normalizedRole == AppRoles.accountant;
  }

  static bool canViewPayments(Object? role) {
    return hasAnyRole(role, paymentRoles);
  }

  static bool canRecordPayments(Object? role) {
    final normalizedRole = AppRoles.normalize(role);

    return normalizedRole == AppRoles.admin ||
        normalizedRole == AppRoles.accountant;
  }

  static bool canViewTechnicians(Object? role) {
    return hasAnyRole(role, technicianRoles);
  }

  static bool canManageTechnicians(Object? role) {
    final normalizedRole = AppRoles.normalize(role);

    return normalizedRole == AppRoles.admin ||
        normalizedRole == AppRoles.serviceManager;
  }
}
