import 'package:flutter/material.dart';
import 'package:on_time_front/shared/components/check_button.dart';
import 'package:on_time_front/shared/components/tile.dart';
import 'package:on_time_front/shared/theme/tile_style.dart';

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
      itemBuilder: (context, index) => Padding(
        key: ValueKey<int>(_items[index]),
        padding: const EdgeInsets.only(bottom: 8.0),
        child: Tile(
            key: ValueKey<int>(_items[index]),
            style: TileStyle(backgroundColor: Color(0xFFE6E9F9)),
            leading: SizedBox(
                width: 30,
                height: 30,
                child: CheckButton(
                  isChecked: true,
                  onPressed: () {},
                )),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 19),
              child: Text('Tile'),
            )),
      ),
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
