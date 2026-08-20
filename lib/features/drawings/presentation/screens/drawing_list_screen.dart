import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../../core/widgets/erp_drawer.dart';
import '../../../../core/widgets/responsive_layout.dart';
import '../../../../core/widgets/responsive_widgets.dart';
import '../../../../core/widgets/polish_widgets.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../domain/models/drawing_model.dart';
import '../providers/drawing_provider.dart';

class DrawingListScreen extends ConsumerStatefulWidget {
  const DrawingListScreen({super.key});

  @override
  ConsumerState<DrawingListScreen> createState() => _DrawingListScreenState();
}

class _DrawingListScreenState extends ConsumerState<DrawingListScreen> {
  late TextEditingController _searchController;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
    // Reset filters on init
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(drawingSearchQueryProvider.notifier).state = '';
      ref.read(drawingTypeFilterProvider.notifier).state = 'All';
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _openPdf(BuildContext context, String url) async {
    try {
      final uri = Uri.parse(url);
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (e) {
      if (context.mounted) {
        showFeedbackSnackBar(
          context: context,
          message: 'Could not open PDF link: $e',
          isError: true,
        );
      }
    }
  }

  void _openImageViewer(BuildContext context, String url, String name) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(12),
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Black backdrop tap to close
            GestureDetector(
              onTap: () => Navigator.of(context).pop(),
              child: Container(
                width: double.infinity,
                height: double.infinity,
                color: Colors.black.withOpacity(0.85),
              ),
            ),
            // Zoomable image container
            InteractiveViewer(
              panEnabled: true,
              boundaryMargin: const EdgeInsets.all(20),
              minScale: 0.5,
              maxScale: 4.0,
              child: Center(
                child: Image.network(
                  url,
                  fit: BoxFit.contain,
                  loadingBuilder: (context, child, loadingProgress) {
                    if (loadingProgress == null) return child;
                    return const Center(child: CircularProgressIndicator(color: Colors.white));
                  },
                  errorBuilder: (context, error, stackTrace) => const Center(
                    child: Text('Failed to load drawing image', style: TextStyle(color: Colors.white)),
                  ),
                ),
              ),
            ),
            // Overlay controls
            Positioned(
              top: 16,
              left: 16,
              right: 16,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.6),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        name,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, color: Colors.white, size: 24),
                    onPressed: () => Navigator.of(context).pop(),
                    style: IconButton.styleFrom(
                      backgroundColor: Colors.black.withOpacity(0.6),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _deleteDrawing(BuildContext context, DrawingModel drawing) async {
    final confirmed = await showDeleteConfirmationDialog(
      context: context,
      recordName: drawing.drawingName,
    );

    if (!confirmed) return;

    final authState = ref.read(authProvider);
    final companyId = authState.user?.companyId;

    if (companyId == null || companyId.isEmpty) {
      if (context.mounted) {
        showFeedbackSnackBar(
          context: context,
          message: 'Error: Company context not found.',
          isError: true,
        );
      }
      return;
    }

    try {
      final storage = ref.read(storageServiceProvider);
      final repo = ref.read(drawingRepositoryProvider);

      // 1. Delete file from Firebase Storage
      if (drawing.storagePath.isNotEmpty) {
        await storage.deleteFile(path: drawing.storagePath);
      }

      // 2. Delete metadata document from Firestore
      await repo.deleteDrawing(companyId, drawing.drawingId);

      if (context.mounted) {
        showFeedbackSnackBar(
          context: context,
          message: 'Drawing "${drawing.drawingName}" deleted successfully.',
        );
      }
    } catch (e) {
      if (context.mounted) {
        showFeedbackSnackBar(
          context: context,
          message: 'Failed to delete drawing: $e',
          isError: true,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final role = authState.selectedRole ?? 'Employee';
    final companyId = authState.user?.companyId ?? '';

    final hasWriteAccess = role == 'Owner' || role == 'HR';
    final hasDeleteAccess = role == 'Owner' || role == 'HR';

    final drawingsAsync = ref.watch(filteredDrawingsProvider);
    final query = ref.watch(drawingSearchQueryProvider);

    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final isMobile = ResponsiveLayout.isMobile(context);

    // Grid config
    final crossAxisCount = isMobile ? 1 : (ResponsiveLayout.isTablet(context) ? 2 : 3);
    final childAspectRatio = isMobile ? 2.8 : 0.85;

    Widget buildBodyContent() {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Filter Chips and Search Row
          Padding(
            padding: const EdgeInsets.only(bottom: AppSizes.p16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                PremiumSearchBar(
                  controller: _searchController,
                  hintText: 'Search drawings by name...',
                  onChanged: (val) => ref.read(drawingSearchQueryProvider.notifier).state = val,
                ),
                const SizedBox(height: 12),
                _buildTypeFilterRow(),
              ],
            ),
          ),

          // Main list or grid
          Expanded(
            child: drawingsAsync.when(
              data: (drawings) {
                if (drawings.isEmpty) {
                  return EmptyStateWidget(
                    icon: Icons.architecture_rounded,
                    title: query.isNotEmpty ? 'No drawings match search' : 'No Drawings Found',
                    description: query.isNotEmpty 
                        ? 'Try modifying your search text to find what you are looking for.' 
                        : 'Store and manage CAD drawings, PDF schematics, and design documents in one central repository.',
                    ctaLabel: hasWriteAccess && query.isEmpty ? 'Upload Drawing' : null,
                    onCtaPressed: hasWriteAccess && query.isEmpty ? () => context.push('/drawings/add') : null,
                  );
                }

                if (isMobile) {
                  return ListView.separated(
                    itemCount: drawings.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      return _buildDrawingMobileCard(drawings[index], hasDeleteAccess, theme, isDark);
                    },
                  );
                }

                return GridView.builder(
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: crossAxisCount,
                    crossAxisSpacing: AppSizes.p16,
                    mainAxisSpacing: AppSizes.p16,
                    childAspectRatio: childAspectRatio,
                  ),
                  itemCount: drawings.length,
                  itemBuilder: (context, index) {
                    return _buildDrawingGridCard(drawings[index], hasDeleteAccess, theme, isDark);
                  },
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, _) => Center(
                child: Text('Error loading drawings: $err', style: TextStyle(color: theme.colorScheme.error)),
              ),
            ),
          ),
        ],
      );
    }

    if (isMobile) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Drawing Library', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
          elevation: 0,
          backgroundColor: theme.colorScheme.surface,
          iconTheme: IconThemeData(color: theme.colorScheme.onSurface),
          actions: [
            if (hasWriteAccess)
              IconButton(
                onPressed: () => context.push('/drawings/add'),
                icon: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.add_rounded, size: 20, color: Colors.white),
                ),
              ),
          ],
        ),
        drawer: const ERPDrawer(),
        body: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          child: buildBodyContent(),
        ),
      );
    }

    return ResponsiveScaffold(
      appBar: AppBar(
        title: const Text('Drawing Management'),
        elevation: 0,
        backgroundColor: theme.colorScheme.surface,
        iconTheme: IconThemeData(color: theme.colorScheme.onSurface),
        actions: [
          if (hasWriteAccess)
            Padding(
              padding: const EdgeInsets.only(right: AppSizes.p16),
              child: ElevatedButton.icon(
                onPressed: () => context.push('/drawings/add'),
                icon: const Icon(Icons.upload_file_rounded),
                label: const Text('Upload Drawing'),
                style: ElevatedButton.styleFrom(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppSizes.buttonRadius),
                  ),
                ),
              ),
            ),
        ],
      ),
      drawer: const ERPDrawer(),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(AppSizes.p24),
            child: Center(
              child: Container(
                constraints: const BoxConstraints(maxWidth: AppSizes.maxContentWidth),
                height: MediaQuery.of(context).size.height - 180, // Dynamic height container to allow scrolling
                child: buildBodyContent(),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTypeFilterRow() {
    final selectedFilter = ref.watch(drawingTypeFilterProvider);
    final filters = ['All', 'PDF', 'Image'];

    return SizedBox(
      height: 36,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: filters.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (ctx, i) {
          final filter = filters[i];
          final isSelected = filter == selectedFilter;
          return ChoiceChip(
            label: Text(filter, style: TextStyle(fontSize: 12, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)),
            selected: isSelected,
            onSelected: (_) => ref.read(drawingTypeFilterProvider.notifier).state = filter,
            selectedColor: Theme.of(context).colorScheme.primary.withOpacity(0.15),
            labelStyle: TextStyle(
              color: isSelected 
                  ? Theme.of(context).colorScheme.primary 
                  : Theme.of(context).textTheme.bodyMedium?.color,
            ),
          );
        },
      ),
    );
  }

  // Beautiful visual block for PDF/Image thumbnail
  Widget _buildThumbnailBlock(DrawingModel drawing, bool isDark) {
    if (drawing.fileType == 'pdf') {
      return Container(
        color: isDark ? Colors.red.shade900.withOpacity(0.2) : Colors.red.shade50,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.picture_as_pdf_rounded, size: 48, color: Colors.red.shade700),
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.red.shade700,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Text(
                  'PDF VIEW',
                  style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold),
                ),
              )
            ],
          ),
        ),
      );
    }

    // It's an image file
    return Image.network(
      drawing.fileUrl,
      fit: BoxFit.cover,
      loadingBuilder: (context, child, loadingProgress) {
        if (loadingProgress == null) return child;
        return Container(
          color: isDark ? Colors.grey.shade900 : Colors.grey.shade100,
          child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
        );
      },
      errorBuilder: (context, error, stackTrace) => Container(
        color: isDark ? Colors.grey.shade900 : Colors.grey.shade100,
        child: Center(
          child: Icon(Icons.image_not_supported_rounded, size: 36, color: Colors.grey.shade400),
        ),
      ),
    );
  }

  // Grid item layout (Desktop / Tablet)
  Widget _buildDrawingGridCard(DrawingModel drawing, bool hasDeleteAccess, ThemeData theme, bool isDark) {
    final formattedDate = DateFormat('dd MMM yyyy').format(drawing.createdAt);

    return Card(
      elevation: 0,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: theme.dividerColor.withAlpha(30)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Visual thumbnail area
          Expanded(
            flex: 5,
            child: InkWell(
              onTap: () {
                if (drawing.fileType == 'pdf') {
                  _openPdf(context, drawing.fileUrl);
                } else {
                  _openImageViewer(context, drawing.fileUrl, drawing.drawingName);
                }
              },
              child: Stack(
                fit: StackFit.expand,
                children: [
                  _buildThumbnailBlock(drawing, isDark),
                  // Visual hover shade overlay
                  Positioned.fill(
                    child: Container(
                      color: Colors.black.withOpacity(0.01),
                    ),
                  ),
                  // File type tag
                  Positioned(
                    top: 10,
                    right: 10,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.7),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        drawing.fileType.toUpperCase(),
                        style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Info section
          Expanded(
            flex: 5,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        drawing.drawingName,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Icon(Icons.person_outline_rounded, size: 14, color: theme.textTheme.bodySmall?.color?.withOpacity(0.6)),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              drawing.uploadedBy,
                              style: TextStyle(fontSize: 11, color: theme.textTheme.bodySmall?.color?.withOpacity(0.7)),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Icon(Icons.calendar_today_rounded, size: 12, color: theme.textTheme.bodySmall?.color?.withOpacity(0.6)),
                          const SizedBox(width: 4),
                          Text(
                            formattedDate,
                            style: TextStyle(fontSize: 11, color: theme.textTheme.bodySmall?.color?.withOpacity(0.7)),
                          ),
                        ],
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () {
                            if (drawing.fileType == 'pdf') {
                              _openPdf(context, drawing.fileUrl);
                            } else {
                              _openImageViewer(context, drawing.fileUrl, drawing.drawingName);
                            }
                          },
                          icon: Icon(
                            drawing.fileType == 'pdf' 
                                ? Icons.open_in_new_rounded 
                                : Icons.remove_red_eye_rounded, 
                            size: 14,
                          ),
                          label: Text(drawing.fileType == 'pdf' ? 'Open PDF' : 'Preview'),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                        ),
                      ),
                      if (hasDeleteAccess) ...[
                        const SizedBox(width: 8),
                        IconButton(
                          onPressed: () => _deleteDrawing(context, drawing),
                          icon: const Icon(Icons.delete_outline_rounded, color: Colors.red),
                          style: IconButton.styleFrom(
                            backgroundColor: Colors.red.withOpacity(0.05),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // List item layout (Mobile)
  Widget _buildDrawingMobileCard(DrawingModel drawing, bool hasDeleteAccess, ThemeData theme, bool isDark) {
    final formattedDate = DateFormat('dd MMM').format(drawing.createdAt);

    return Card(
      elevation: 0,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: theme.dividerColor.withAlpha(20)),
      ),
      child: InkWell(
        onTap: () {
          if (drawing.fileType == 'pdf') {
            _openPdf(context, drawing.fileUrl);
          } else {
            _openImageViewer(context, drawing.fileUrl, drawing.drawingName);
          }
        },
        child: Container(
          height: 90,
          child: Row(
            children: [
              // Icon block
              Container(
                width: 90,
                height: double.infinity,
                child: _buildThumbnailBlock(drawing, isDark),
              ),
              const SizedBox(width: AppSizes.p12),
              // Details
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        drawing.drawingName,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        'By: ${drawing.uploadedBy} • $formattedDate',
                        style: TextStyle(fontSize: 11, color: theme.textTheme.bodySmall?.color?.withOpacity(0.6)),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ),
              // Deletion action
              if (hasDeleteAccess)
                Padding(
                  padding: const EdgeInsets.only(right: 8.0),
                  child: IconButton(
                    icon: const Icon(Icons.delete_outline_rounded, color: Colors.red, size: 20),
                    onPressed: () => _deleteDrawing(context, drawing),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
