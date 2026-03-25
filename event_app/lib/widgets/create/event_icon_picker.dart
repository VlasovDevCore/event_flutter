import 'package:flutter/material.dart';

class EventIconPicker extends StatelessWidget {
  const EventIconPicker({
    super.key,
    required this.icons,
    required this.selectedIcon,
    required this.onIconSelected,
  });

  final List<IconData> icons;
  final IconData selectedIcon;
  final ValueChanged<IconData> onIconSelected;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Иконка',
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
              itemCount: icons.length,
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: crossAxisCount,
                crossAxisSpacing: spacing,
                mainAxisSpacing: spacing,
                childAspectRatio: 1,
              ),
              itemBuilder: (context, index) {
                final i = icons[index];
                final selected = i.codePoint == selectedIcon.codePoint;
                return InkWell(
                  onTap: () => onIconSelected(i),
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E1E1E),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: selected
                            ? Theme.of(context).colorScheme.primary
                            : Colors.transparent,
                        width: 2,
                      ),
                    ),
                    child: Icon(i),
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
