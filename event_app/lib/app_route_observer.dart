import 'package:flutter/material.dart';

/// Для [RouteAware] (например обновление «Мои события» при возврате с чата/деталей).
final RouteObserver<ModalRoute<void>> appRouteObserver =
    RouteObserver<ModalRoute<void>>();
