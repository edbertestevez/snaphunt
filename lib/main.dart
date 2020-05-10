import 'package:camera/camera.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:snaphunt/data/repository.dart';
import 'package:snaphunt/routes.dart';
import 'package:snaphunt/services/auth.dart';
import 'package:snaphunt/services/connectivity.dart';
import 'package:snaphunt/ui/home.dart';
import 'package:snaphunt/ui/login.dart';
import 'package:snaphunt/utils/utils.dart';
import 'package:snaphunt/widgets/common/custom_scroll.dart';

List<CameraDescription> cameras;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  cameras = await availableCameras();
  openDB().then((_) async {
    initDB();
    runApp(App(auth: await Auth.create()));
  });
}

class App extends StatefulWidget {
  const App({
    Key key,
    @required this.auth,
  }) : super(key: key);

  final Auth auth;

  @override
  _AppState createState() => _AppState();
}

class _AppState extends State<App> {
  final _navigatorKey = GlobalKey<NavigatorState>();
  FirebaseUser currentUser;

  @override
  void initState() {
    super.initState();
    Repository.instance.updateLocalWords();
    currentUser = widget.auth.init(_onUserChanged);
  }

  void _onUserChanged() {
    final user = widget.auth.currentUser.value;

    if (currentUser == null && user != null) {
      Repository.instance.updateUserData(user);
      _navigatorKey.currentState
          .pushAndRemoveUntil(Home.route(), (route) => false);
    } else if (currentUser != null && user == null) {
      _navigatorKey.currentState
          .pushAndRemoveUntil(Login.route(), (route) => false);
    }
    currentUser = user;
  }

  @override
  void dispose() {
    widget.auth.dispose(_onUserChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider<Auth>.value(value: widget.auth),
        ValueListenableProvider<FirebaseUser>.value(
            value: widget.auth.currentUser),
        StreamProvider<ConnectivityStatus>(
          create: (_) =>
              ConnectivityService().connectionStatusController.stream,
        ),
      ],
      child: MaterialApp(
        title: 'SnapHunt',
        theme: ThemeData(
          primaryColor: Colors.orange,
          fontFamily: 'SF_Atarian_System',
        ),
        navigatorKey: _navigatorKey,
        onGenerateRoute: Router.generateRoute,
        builder: (context, child) {
          return ScrollConfiguration(
            behavior: NoOverFlowScrollBehavior(),
            child: child,
          );
        },
        home: currentUser == null ? const Login() : const Home(),
      ),
    );
  }
}
