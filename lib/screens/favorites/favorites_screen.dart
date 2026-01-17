import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../controllers/favorites_controller.dart';
import '../../models/favorite.dart';
import '../../models/content_type.dart';
import '../../models/playlist_content_model.dart';
import '../../models/live_stream.dart';
import '../../models/vod_streams.dart';
import '../../models/series.dart';
import '../../models/m3u_item.dart';
import '../../widgets/content_card.dart';
import '../../utils/navigate_by_content_type.dart';
import '../../utils/responsive_helper.dart';
import '../../utils/get_playlist_type.dart';
import '../../l10n/localization_extension.dart';
import '../../repositories/favorites_repository.dart';

class FavoritesScreen extends StatelessWidget {
  final String playlistId;
  final Key? screenKey;

  const FavoritesScreen({
    super.key,
    required this.playlistId,
    this.screenKey,
  });

  @override
  Widget build(BuildContext context) {
    // Use the FavoritesController from the parent provider (xtream_code_home_screen or m3u_home_screen)
    return Scaffold(
      body: Consumer<FavoritesController>(
        builder: (context, controller, child) {
            if (controller.isLoading) {
              return const Center(child: CircularProgressIndicator());
            }

            if (controller.error != null) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(controller.error!)),
                );
              });
            }

          return RefreshIndicator(
            onRefresh: () async {
              await controller.loadFavorites();
            },
            child: controller.favorites.isEmpty
                ? _buildEmptyState(context)
                : _buildContent(context, controller),
          );
        },
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.favorite_border,
              size: 64,
              color: Theme.of(context).colorScheme.outline,
            ),
            const SizedBox(height: 16),
            Text(
              context.loc.no_favorites,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: Theme.of(context).colorScheme.outline,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              context.loc.add_favorites_hint,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.outline,
                  ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent(BuildContext context, FavoritesController controller) {
    final cardWidth = ResponsiveHelper.getCardWidth(context);
    final cardHeight = ResponsiveHelper.getCardHeight(context);

    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (controller.liveStreamFavorites.isNotEmpty)
            _buildSection(
              context,
              context.loc.live_streams,
              controller.liveStreamFavorites,
              cardWidth,
              cardHeight,
            ),
          if (controller.movieFavorites.isNotEmpty)
            _buildSection(
              context,
              context.loc.movies,
              controller.movieFavorites,
              cardWidth,
              cardHeight,
            ),
          if (controller.seriesFavorites.isNotEmpty)
            _buildSection(
              context,
              context.loc.series_plural,
              controller.seriesFavorites,
              cardWidth,
              cardHeight,
            ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildSection(
    BuildContext context,
    String title,
    List<Favorite> favorites,
    double cardWidth,
    double cardHeight,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Text(
            title,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
        ),
        SizedBox(
          height: cardHeight + 16,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            itemCount: favorites.length,
            itemBuilder: (context, index) {
              final favorite = favorites[index];
              return _buildFavoriteCard(context, favorite, cardWidth, cardHeight);
            },
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildFavoriteCard(
    BuildContext context,
    Favorite favorite,
    double cardWidth,
    double cardHeight,
  ) {
    return Container(
      width: cardWidth,
      height: cardHeight,
      margin: const EdgeInsets.symmetric(horizontal: 4),
      child: FutureBuilder<ContentItem?>(
        future: _getContentItemFromFavorite(favorite),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Container(
              width: cardWidth,
              height: cardHeight,
              decoration: BoxDecoration(
                color: Colors.grey.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Center(
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            );
          }

          final contentItem =
              snapshot.data ?? _convertFavoriteToContentItem(favorite);

          return ContentCard(
            content: contentItem,
            width: cardWidth,
            isFavorite: true,
            onTap: () => _navigateToContent(context, contentItem),
          );
        },
      ),
    );
  }

  ContentItem _convertFavoriteToContentItem(Favorite favorite) {
    if (isXtreamCode) {
      switch (favorite.contentType) {
        case ContentType.liveStream:
          final liveStream = LiveStream(
            streamId: favorite.streamId,
            name: favorite.name,
            streamIcon: favorite.imagePath ?? '',
            categoryId: '',
            epgChannelId: '',
          );
          return ContentItem(
            favorite.streamId,
            favorite.name,
            favorite.imagePath ?? '',
            favorite.contentType,
            liveStream: liveStream,
          );

        case ContentType.vod:
          final vodStream = VodStream(
            streamId: favorite.streamId,
            name: favorite.name,
            streamIcon: favorite.imagePath ?? '',
            categoryId: '',
            rating: '',
            rating5based: 0.0,
            containerExtension: '',
            createdAt: DateTime.now(),
          );
          return ContentItem(
            favorite.streamId,
            favorite.name,
            favorite.imagePath ?? '',
            favorite.contentType,
            vodStream: vodStream,
          );

        case ContentType.series:
          final seriesStream = SeriesStream(
            seriesId: favorite.streamId,
            name: favorite.name,
            cover: favorite.imagePath ?? '',
            categoryId: '',
            playlistId: favorite.playlistId,
          );
          return ContentItem(
            favorite.streamId,
            favorite.name,
            favorite.imagePath ?? '',
            favorite.contentType,
            seriesStream: seriesStream,
          );
      }
    } else if (isM3u) {
      final m3uItem = M3uItem(
        id: favorite.m3uItemId ?? favorite.streamId,
        playlistId: favorite.playlistId,
        url: favorite.streamId,
        contentType: favorite.contentType,
        name: favorite.name,
        tvgLogo: favorite.imagePath,
      );
      return ContentItem(
        favorite.streamId,
        favorite.name,
        favorite.imagePath ?? '',
        favorite.contentType,
        m3uItem: m3uItem,
      );
    }

    return ContentItem(
      favorite.streamId,
      favorite.name,
      favorite.imagePath ?? '',
      favorite.contentType,
    );
  }

  Future<ContentItem?> _getContentItemFromFavorite(Favorite favorite) async {
    final repository = FavoritesRepository();
    return await repository.getContentItemFromFavorite(favorite);
  }

  void _navigateToContent(BuildContext context, ContentItem contentItem) {
    navigateByContentType(context, contentItem);
  }
}
