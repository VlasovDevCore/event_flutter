import 'package:flutter/material.dart';
import '../../config/event_marker_catalog.dart';

class EventColorPicker extends StatelessWidget {
  const EventColorPicker({
    super.key,
    required this.selectedColor,
    required this.onColorSelected,
  });

  final Color selectedColor;
  final ValueChanged<Color> onColorSelected;

  @override
  Widget build(BuildContext context) {
    final colors = EventMarkerCatalog.availableColors;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Цвет',
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
            height: 1,
            fontFamily: 'Inter',
            fontWeight: FontWeight.w400,
            fontSize: 13,
          ),
        ),
        const SizedBox(height: 10),
        LayoutBuilder(
          builder: (context, constraints) {
            const spacing = 6.0;
            const minColumns = 6;
            const minTileSize = 44.0;
            final calculatedColumns =
                ((constraints.maxWidth + spacing) / (minTileSize + spacing))
                    .floor();
            final crossAxisCount = calculatedColumns < minColumns
                ? minColumns
                : calculatedColumns;

            return GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              padding: EdgeInsets.zero,
              itemCount: colors.length,
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: crossAxisCount,
                crossAxisSpacing: spacing,
                mainAxisSpacing: spacing,
                childAspectRatio: 1,
              ),
              itemBuilder: (context, index) {
                final c = colors[index];
                final selected = c.value == selectedColor.value;
                return InkWell(
                  onTap: () => onColorSelected(c),
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    decoration: BoxDecoration(
                      color: c,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: selected ? Colors.white : Colors.transparent,
                        width: 2,
                      ),
                    ),
                    child: selected
                        ? const Center(
                            child: Icon(
                              Icons.check,
                              color: Colors.white,
                              size: 16,
                            ),
                          )
                        : null,
                  ),
                );
              },
            );
          },
        ),
      ],
    );
  }
}
