import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:dio_cache_interceptor/dio_cache_interceptor.dart';
import 'package:dio_cache_interceptor_hive_store/dio_cache_interceptor_hive_store.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shimmer/shimmer.dart';

class InfiniteScrollPosts extends StatefulWidget {
  const InfiniteScrollPosts({super.key});

  @override
  InfiniteScrollPostsState createState() => InfiniteScrollPostsState();
}

class InfiniteScrollPostsState extends State<InfiniteScrollPosts> {
  late Dio _dio;
  late CacheOptions _cacheOptions;

  final List posts = [];
  int currentPage = 0;
  final int pageSize = 5;
  bool isLoading = false;
  bool hasMore = true;
  bool isError = false;

  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();

    // Initialize Hive
    _initializeHive();

    // Add scroll listener
    _scrollController.addListener(() {
      if (_scrollController.position.pixels >=
          _scrollController.position.maxScrollExtent &&
          !isLoading &&
          hasMore) {
        _fetchPosts();
      }
    });
  }

  Future<void> _initializeHive() async {
    await Hive.initFlutter(); // Initialize Hive for Flutter

    // Initialize cache options with HiveCacheStore
    _cacheOptions = CacheOptions(
      store: HiveCacheStore(await getTemporaryDirectoryPath()), // Directory for cache
      policy: CachePolicy.request,
      hitCacheOnErrorExcept: [401, 403],
      maxStale: const Duration(days: 7),
    );

    _dio = Dio()..interceptors.add(DioCacheInterceptor(options: _cacheOptions));

    // Fetch initial data
    _fetchPosts();
  }

  Future<String> getTemporaryDirectoryPath() async {
    final dir = await getTemporaryDirectory();
    return dir.path; // Path to temporary directory for caching
  }

  Future<void> _fetchPosts({bool isRefresh = false}) async {
    if (isLoading) return;

    setState(() {
      isLoading = true;
      isError = false;
      if (isRefresh) {
        posts.clear();
        currentPage = 0;
        hasMore = true;
      }
    });

    final url =
        'http://localhost:8080/todos?_start=${currentPage * pageSize}&_limit=$pageSize';

    try {
      final response = await _dio.get(url, options: _cacheOptions.toOptions());

      if (response.statusCode == 200) {
        final List newPosts = response.data;

        setState(() {
          posts.addAll(newPosts);
          currentPage++; // Increment the current page
          if (newPosts.length < pageSize) {
            hasMore = false; // No more posts if the response length is less than pageSize
          }
        });
      } else {
        throw Exception("Failed to fetch posts");
      }
    } catch (e) {
      setState(() {
        isError = true;
      });
      debugPrint("Error fetching posts: $e");
    }

    setState(() {
      isLoading = false;
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    Hive.close(); // Close Hive box
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Infinite Scroll Posts"),
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          await _fetchPosts(isRefresh: true);
        },
        child: isError && posts.isEmpty
            ? Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                "Failed to load data",
                style: TextStyle(color: Colors.red, fontSize: 16),
              ),
              const SizedBox(height: 8),
              ElevatedButton(
                onPressed: () => _fetchPosts(isRefresh: true),
                child: const Text("Retry"),
              ),
            ],
          ),
        )
            : ListView.builder(
          controller: _scrollController,
          itemCount: posts.length + (hasMore ? 1 : 0),
          itemBuilder: (context, index) {
            if (index < posts.length) {
              final post = posts[index];
              return Container(
                decoration: BoxDecoration(
                  borderRadius: const BorderRadius.all(Radius.circular(16)),
                  color: Colors.purple.shade300,
                ),
                height: 200,
                margin: const EdgeInsets.symmetric(horizontal: 15, vertical: 10),
                child: ListTile(
                  title: Text(post['id'].toString(), style: const TextStyle(fontSize: 34, fontWeight: FontWeight.w600, color: Colors.white)),
                  subtitle: Text(post['name']),
                ),
              );
            } else if (hasMore && isLoading) {
              return ListView.builder(itemCount:10, itemBuilder: (_, index){
                return _buildLoadingShimmer();
              });
            } else {
              return const SizedBox.shrink();
            }
          },
        ),
      ),
    );
  }

  Widget _buildLoadingShimmer() {
    return Shimmer.fromColors(
      baseColor: Colors.grey[300]!,
      highlightColor: Colors.grey[100]!,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: const BorderRadius.all(Radius.circular(16)),
          color: Colors.grey[300],
        ),
        height: 200,
        margin: const EdgeInsets.symmetric(horizontal: 15, vertical: 10),
        width: double.infinity,

      ),
    );
  }
}


void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MaterialApp(
    debugShowCheckedModeBanner: false,
    home: InfiniteScrollPosts(),
  ));
}



