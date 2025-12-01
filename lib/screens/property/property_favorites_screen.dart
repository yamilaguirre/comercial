import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../theme/theme.dart';
import '../../services/saved_list_service.dart';
import '../../providers/auth_provider.dart';
import '../../models/contact_filter.dart';
import 'components/saved_counter.dart';
import 'tabs/all_saved_tab.dart';
import 'tabs/collections_tab.dart';

class PropertyFavoritesScreen extends StatefulWidget {
  const PropertyFavoritesScreen({super.key});

  @override
  State<PropertyFavoritesScreen> createState() =>
      _PropertyFavoritesScreenState();
}

class _PropertyFavoritesScreenState extends State<PropertyFavoritesScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final SavedListService _savedListService = SavedListService();

  // Contact filter state
  ContactFilter _selectedFilter = ContactFilter.all;
  Map<ContactFilter, int> _counts = {
    ContactFilter.all: 0,
    ContactFilter.contacted: 0,
    ContactFilter.notContacted: 0,
  };

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadCounts();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadCounts() async {
    final authService = Provider.of<AuthService>(context, listen: false);
    final userId = authService.currentUser?.uid ?? '';

    final counts = await _savedListService.getContactStatusCounts(userId);
    if (mounted) {
      setState(() {
        _counts = counts;
      });
    }
  }

  void _onFilterChanged(ContactFilter filter) {
    setState(() {
      _selectedFilter = filter;
    });
  }

  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context);
    final userId = authService.currentUser?.uid ?? '';

    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: SafeArea(
        child: Column(
          children: [
            // HEADER
            Container(
              color: Colors.white,
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Título y búsqueda
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Guardados',
                        style: TextStyle(
                          color: Colors.black,
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.search, color: Colors.black),
                        onPressed: () {
                          // TODO: Implementar búsqueda
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // Tabs - Optimizado
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: TabBar(
                      controller: _tabController,
                      indicator: BoxDecoration(
                        color: Styles.primaryColor,
                        borderRadius: BorderRadius.circular(10),
                        boxShadow: [
                          BoxShadow(
                            color: Styles.primaryColor.withOpacity(0.3),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      indicatorSize: TabBarIndicatorSize.tab,
                      labelColor: Colors.white,
                      unselectedLabelColor: Colors.grey[700],
                      labelStyle: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.3,
                      ),
                      unselectedLabelStyle: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                      ),
                      labelPadding: const EdgeInsets.symmetric(horizontal: 8),
                      dividerColor: Colors.transparent,
                      splashFactory: NoSplash.splashFactory,
                      overlayColor: MaterialStateProperty.all(
                        Colors.transparent,
                      ),
                      tabs: const [
                        Tab(
                          height: 44,
                          child: Center(
                            child: Text(
                              'Todo Guardado',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                        Tab(
                          height: 44,
                          child: Center(
                            child: Text(
                              'Mis Colecciones',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Contadores de filtro (solo en la pestaña "Todo Guardado")
                  AnimatedBuilder(
                    animation: _tabController,
                    builder: (context, child) {
                      if (_tabController.index == 0) {
                        return Column(
                          children: [
                            SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: Row(
                                children: [
                                  SavedCounter(
                                    icon: Icons.favorite,
                                    label: ContactFilter.all.label,
                                    count: _counts[ContactFilter.all] ?? 0,
                                    color: Styles.primaryColor,
                                    isSelected:
                                        _selectedFilter == ContactFilter.all,
                                    onTap: () =>
                                        _onFilterChanged(ContactFilter.all),
                                  ),
                                  const SizedBox(width: 12),
                                  SavedCounter(
                                    icon: Icons.chat_bubble_outline,
                                    label: ContactFilter.notContacted.label,
                                    count:
                                        _counts[ContactFilter.notContacted] ??
                                        0,
                                    color: Colors.orange,
                                    isSelected:
                                        _selectedFilter ==
                                        ContactFilter.notContacted,
                                    onTap: () => _onFilterChanged(
                                      ContactFilter.notContacted,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  SavedCounter(
                                    icon: Icons.chat,
                                    label: ContactFilter.contacted.label,
                                    count:
                                        _counts[ContactFilter.contacted] ?? 0,
                                    color: Colors.green,
                                    isSelected:
                                        _selectedFilter ==
                                        ContactFilter.contacted,
                                    onTap: () => _onFilterChanged(
                                      ContactFilter.contacted,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 16),
                          ],
                        );
                      }
                      return const SizedBox(height: 16);
                    },
                  ),
                ],
              ),
            ),

            // TABS CONTENT
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  AllSavedTab(userId: userId, filter: _selectedFilter),
                  CollectionsTab(
                    userId: userId,
                    onCollectionChanged: _loadCounts,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
