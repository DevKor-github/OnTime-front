import 'package:flutter/material.dart';
import 'package:on_time_front/shared/components/Tile.dart';
import 'package:on_time_front/shared/theme/theme.dart';

class PreparationReorderableList extends StatefulWidget {
  const PreparationReorderableList({super.key});

  @override
  State<PreparationReorderableList> createState() => _ReoderableListingState();
}

class _ReoderableListingState extends State<PreparationReorderableList> {
  final List<int> _items = List<int>.generate(50, (int index) => index);

  @override
  Widget build(BuildContext context) {
    Widget proxyDecorator(
        Widget child, int index, Animation<double> animation) {
      return AnimatedBuilder(
        animation: animation,
        builder: (BuildContext context, Widget? child) {
          return SizedBox(
            child: child,
          );
        },
        child: child,
      );
    }

    return ReorderableListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 40),
      proxyDecorator: proxyDecorator,
      itemCount: _items.length,
      itemBuilder: (context, index) => Tile(
          key: ValueKey<int>(_items[index]),
          leading: const SizedBox(
            width: 30,
            height: 30,
            child: CircleAvatar(
              child: Icon(Icons.check),
            ),
          ),
          style: TileStyle(
            padding: const EdgeInsets.all(16.0),
            margin: const EdgeInsets.only(bottom: 8.0),
            borderRadius: BorderRadius.circular(32),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 19.0),
            child: Text('Item ${_items[index]}'),
          )),
      onReorder: (int oldIndex, int newIndex) {
        setState(() {
          if (oldIndex < newIndex) {
            newIndex -= 1;
          }
          final int item = _items.removeAt(oldIndex);
          _items.insert(newIndex, item);
        });
      },
    );
  }
}
