import 'dart:math';

import 'package:flutter/material.dart';
import 'package:paginated_items_builder/src/models/paginated_items_builder_config.dart';
import 'package:paginated_items_builder/src/models/paginated_items_response.dart';
import 'package:paginated_items_builder/src/pagination_items_state_handler.dart';
import 'package:shimmer/shimmer.dart';
import 'package:visibility_detector/visibility_detector.dart';

import '../paginated_items_builder.dart';

/// Handles rendering the items on the screen. Can have [PaginationItemsStateHandler]
/// as parent if state is not handled externally.
class SliverPaginatedItemsBuilder<T> extends StatefulWidget {
  const SliverPaginatedItemsBuilder({
    Key? key,
    required this.fetchPageData,
    required this.response,
    required this.itemBuilder,
    this.itemsDisplayType = ItemsDisplayType.list,
    this.paginate = true,
    this.showRefreshIcon = true,
    this.loader = const Center(
      child: CircularProgressIndicator.adaptive(),
    ),
    this.loaderItemsCount = 6,
    this.emptyText,
    this.maxLength,
    this.separatorWidget,
    this.listItemsGap,
    this.withRefreshIndicator = true,
    this.gridCrossAxisCount,
    this.gridMainAxisSpacing,
    this.gridCrossAxisSpacing,
    this.gridChildAspectRatio,
    this.gridDelegate,
  }) : super(key: key);

  /// This is the controller function that should handle fetching the list
  /// and updating in the state.
  ///
  /// The boolean in the callback is the reset flag. If that is true, that means
  /// either the user wants to refresh the list with pull-down refresh, or no items
  /// were found, and user clicked the refresh icon.
  ///
  /// If state is handled using [PaginationItemsStateHandler],
  /// then the builder in it provides this argument and should be passed directly.
  final Future<void> Function(bool reset) fetchPageData;

  /// Callback function which requires a widget that is rendered for each item.
  /// Provides context, index of the item in the list and the item itself.
  final Widget Function(BuildContext, int, T) itemBuilder;

  /// The response object whose contents are displayed.
  final PaginatedItemsResponse<T>? response;

  /// The text to show if no items are present.
  final String? emptyText;

  /// If no items are there to display, shows a refresh icon to again call the
  /// API to update the results.
  final bool showRefreshIcon;

  /// RefreshIndicator is avaliable
  final bool withRefreshIndicator;

  /// Whether to paginate a specific list of items or not. Defaults to true.
  final bool paginate;

  /// Separator for items in a list view.
  final Widget? separatorWidget;

  /// Limits the item count no matter what the length of the content is in the
  /// [response.items].
  final int? maxLength;

  /// The number of loader widgets to render before the data is fetched for the
  /// first time.
  final int loaderItemsCount;

  /// Whether to display items in a list view or grid view.
  final ItemsDisplayType itemsDisplayType;

  /// The loader to render if mockItem not found from [PaginatedItemsBuilderConfig].
  final Widget loader;

  /// config
  static PaginatedItemsBuilderConfig? config;

  /// The gap between concurrent list items.
  /// Has no effect if [separatorWidget] is not null.
  final double? listItemsGap;

  // grid
  final int? gridCrossAxisCount;
  final double? gridMainAxisSpacing;
  final double? gridCrossAxisSpacing;
  final double? gridChildAspectRatio;

  /// A delegate that controls the layout of the children within the [GridView].
  ///
  /// The [GridView], [GridView.builder], and [GridView.custom] constructors let you specify this
  /// delegate explicitly. The other constructors create a [gridDelegate]
  /// implicitly.
  final SliverGridDelegate? gridDelegate;

  @override
  _SliverPaginatedItemsBuilderState<T> createState() => _SliverPaginatedItemsBuilderState<T>();
}

class _SliverPaginatedItemsBuilderState<T> extends State<SliverPaginatedItemsBuilder<T>> {
  bool _initialLoading = true;
  bool _loadingMoreData = false;

  final _loaderKey = UniqueKey();

  late bool showLoader;
  late ScrollPhysics? scrollPhysics;
  late int itemCount;
  late T? mockItem;

  Future<void> fetchData({bool reset = false}) async {
    if (!mounted) return;
    if (!reset && (widget.response != null && !widget.response!.hasMoreData && !_loadingMoreData)) return;
    setState(() {
      if (_initialLoading) {
        _initialLoading = false;
      } else if (reset) {
        _initialLoading = true;
      } else {
        _loadingMoreData = true;
      }
    });

    try {
      await widget.fetchPageData(reset);
    } catch (_) {}

    if (_initialLoading) _initialLoading = false;
    if (_loadingMoreData) _loadingMoreData = false;
    try {
      setState(() {});
    } catch (_) {}
  }

  Widget _itemBuilder(context, index) {
    if (widget.response?.items != null) {
      if (widget.response!.items!.length <= index) return _loaderBuilder();
      final item = widget.response!.items![index];
      return widget.itemBuilder(context, index, item);
    } else {
      return _loaderBuilder();
    }
  }

  Widget _loaderBuilder() {
    Widget _buildLoader() => mockItem != null
        ? Shimmer.fromColors(
            highlightColor: SliverPaginatedItemsBuilder.config!.shimmerConfig.highlightColor,
            baseColor: SliverPaginatedItemsBuilder.config!.shimmerConfig.baseColor,
            period: SliverPaginatedItemsBuilder.config!.shimmerConfig.period,
            child: IgnorePointer(
              child: widget.itemBuilder(context, 0, mockItem!),
            ),
          )
        : widget.loader;

    return widget.paginate
        ? VisibilityDetector(
            key: _loaderKey,
            onVisibilityChanged: (_) => fetchData(),
            child: _buildLoader(),
          )
        : _buildLoader();
  }

  Widget _emptyWidget([String? text]) {
    final itemName = T.toString().toLowerCase().replaceAll('lean', '');
    return Center(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            text ?? SliverPaginatedItemsBuilder.config!.noItemsTextGetter(itemName),
            style: SliverPaginatedItemsBuilder.config!.noItemsTextStyle,
          ),
          if (widget.showRefreshIcon)
            IconButton(
              icon: Icon(
                Icons.refresh,
                color: Theme.of(context).colorScheme.secondary,
              ),
              onPressed: () => fetchData(reset: true),
            ),
        ],
      ),
    );
  }

  @override
  void initState() {
    mockItem = SliverPaginatedItemsBuilder.config?.mockItemGetter<T>();

    if (widget.response?.items == null) fetchData();

    SliverPaginatedItemsBuilder.config ??= PaginatedItemsBuilderConfig.defaultConfig();

    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    showLoader = (widget.paginate && (widget.response?.hasMoreData ?? false));

    (() {
      final _itemsLen = (widget.response?.items?.length ?? widget.loaderItemsCount) + (showLoader ? 1 : 0);
      itemCount = widget.maxLength == null ? _itemsLen : min(_itemsLen, widget.maxLength!);
    })();

    if (widget.response?.items?.isEmpty ?? false) {
      return SliverToBoxAdapter(child: _emptyWidget(widget.emptyText));
    } else if (widget.response?.items == null && mockItem == null) {
      return SliverToBoxAdapter(child: _emptyWidget(widget.emptyText));
    } else if (!widget.withRefreshIndicator) {
      return _buildItems();
    } else {
      return SliverToBoxAdapter(
          child: RefreshIndicator(
        displacement: 10,
        onRefresh: () async => await fetchData(reset: true),
        child: _buildItems(),
      ));
    }
  }

  Widget _buildItems() => widget.itemsDisplayType == ItemsDisplayType.list ? _buildListView() : _buildGridView();

  static int _computeActualChildCount(int itemCount) {
    return max(0, itemCount * 2 - 1);
  }

  SliverList _buildListView() {
    var childrenDelegate = SliverChildBuilderDelegate(
      (BuildContext context, int index) {
        final int itemIndex = index ~/ 2;
        final Widget widgetItem;
        if (index.isEven) {
          widgetItem = _itemBuilder(context, itemIndex);
        } else {
          widgetItem = widget.separatorWidget ??
              SizedBox(
                width: widget.listItemsGap,
                height: widget.listItemsGap,
              );
        }
        return widgetItem;
      },
      childCount: _computeActualChildCount(itemCount),
      semanticIndexCallback: (Widget _, int index) {
        return index.isEven ? index ~/ 2 : null;
      },
    );
    return SliverList(delegate: childrenDelegate);
  }

  SliverGrid _buildGridView() {
    return SliverGrid(
      delegate: SliverChildBuilderDelegate(
        _itemBuilder,
        childCount: itemCount,
      ),
      gridDelegate: widget.gridDelegate ??
          SliverGridDelegateWithFixedCrossAxisCount(
            childAspectRatio: widget.gridChildAspectRatio ?? 1,
            crossAxisCount: widget.gridCrossAxisCount ?? 2,
            mainAxisSpacing: widget.gridMainAxisSpacing ?? 15,
            crossAxisSpacing: widget.gridCrossAxisSpacing ?? 15,
          ),
    );
  }
}
