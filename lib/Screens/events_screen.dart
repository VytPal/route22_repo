import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:moto_events/Models/event.dart';
import 'package:moto_events/Screens/event_details.dart';
import 'package:moto_events/Services/event_service.dart';
import 'package:provider/provider.dart';

enum SortOption { startDateOldestNewest, startDateNewestOldest, nameAsc, nameDesc }

extension SortOptionExtension on SortOption {
  String get displayTitle {
    switch (this) {
      case SortOption.startDateOldestNewest:
        return 'Starting Date (Oldest -> Newest)';
      case SortOption.startDateNewestOldest:
        return 'Starting Date (Newest -> Oldest)';
      case SortOption.nameAsc:
        return 'Name (A-Z)';
      case SortOption.nameDesc:
        return 'Name (Z-A)';
      default:
        return '';
    }
  }
}

class EventListPage extends StatefulWidget {
  const EventListPage({Key? key}) : super(key: key);

  @override
  EventListPageState createState() => EventListPageState();
}

class EventListPageState extends State<EventListPage> {
  List<Event> allEvents = [];
  List<Event> filteredEvents = [];
  TextEditingController searchController = TextEditingController();
  SortOption? _selectedSortOption;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    fetchEvents();
  }
  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }
  void _sortAndScrollToTop() {
    _scrollController.animateTo(
      0.0,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
    );
  }

  Future<void> fetchEvents() async {
    try {
      var events = await context.read<EventsService>().fetchEvents();
      setState(() {
        allEvents = events;
        filteredEvents = allEvents;
      });
    } catch (error) {}
  }
  void _sortEvents(SortOption sortOption) {
    setState(() {
      _selectedSortOption = sortOption;
      switch (sortOption) {
        case SortOption.startDateOldestNewest:
          filteredEvents.sort((a, b) => a.startTime!.compareTo(b.startTime!));
          break;
        case SortOption.startDateNewestOldest:
          filteredEvents.sort((a, b) => b.startTime!.compareTo(a.startTime!));
          break;
        case SortOption.nameAsc:
          filteredEvents.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
          break;
        case SortOption.nameDesc:
          filteredEvents.sort((a, b) => b.name.toLowerCase().compareTo(a.name.toLowerCase()));
          break;
      }
    });
  }

  void _showSortOptions(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Center(child: Text('Sort by')),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: SortOption.values.map((option) {
                return RadioListTile<SortOption>(
                  value: option,
                  groupValue: _selectedSortOption,
                  title: Text(option.displayTitle),
                  onChanged: (value) {
                    Navigator.of(context).pop();
                    _sortAndScrollToTop();
                    if (value != null) {
                      _sortEvents(value);
                    }
                  },
                );
              }).toList(),
            ),
          ),
        );
      },
    );
  }
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              children: [
                Expanded(
                  child: CupertinoSearchTextField(
                    style: const TextStyle(color: Colors.white),
                    controller: searchController,
                    placeholder: 'Search',
                    prefixInsets: const EdgeInsets.symmetric(horizontal: 12),
                    prefixIcon: const Icon(CupertinoIcons.search),
                    onChanged: onSearchTextChanged,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.sort),
                  onPressed: () => _showSortOptions(context),
                ),
              ],
            ),
          ),
          Expanded(
            child: allEvents.isEmpty
                ? const Center(child: CircularProgressIndicator())
                : ListView.builder(
              controller: _scrollController,
              key: ValueKey(searchController.text),
              itemCount: filteredEvents.length,
              itemBuilder: (context, index) {
                Event event = filteredEvents[index];
                return eventCard(context, event);
              },
            ),
          ),
          Text('Filtered Events Count: ${filteredEvents.length}'),
        ],
      ),
    );
  }


  void onSearchTextChanged(String query) {
    setState(() {
      filteredEvents = query.isEmpty
          ? List.from(allEvents)
          : allEvents.where((event) => event.name.toLowerCase().contains(query.toLowerCase())).toList();

    });
  }

  Widget eventCard(BuildContext context, Event event) {
    return InkWell(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => EventDetailScreen(event: event)),
        );
      },
      child: Card(
        key: Key(event.id.toString()),
        elevation: 4.0,
        margin: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 6.0),
        child: Column(
          children: [
            if (event.imageUrl.isNotEmpty)
              Image.network(
                event.imageUrl,
                fit: BoxFit.cover,
                errorBuilder: (BuildContext context, Object exception, StackTrace? stackTrace) {
                  return  Container();
                },
              ),
            ListTile(
              title: Text(
                event.name,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "${event.description.split(" ").take(5).join(" ")}...",
                  ),
                  Text(
                    "Start Date: ${DateFormat('yyyy-MM-dd').format(event.startTime!)}",
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              trailing: registrationButton(context, event),
            ),
          ],
        ),
      ),
    );
  }

  Widget registrationButton(BuildContext context, Event event) {
    return ElevatedButton(
      onPressed: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => EventDetailScreen(event: event)),
        );
      },
      style: ElevatedButton.styleFrom(
        primary: Colors.blue,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20.0),
        ),
      ),
      child: const Text(
        'Details',
        style: TextStyle(color: Colors.white),
      ),
    );
  }
}
