import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:snaphunt/constants/game_status_enum.dart';
import 'package:snaphunt/data/repository.dart';
import 'package:snaphunt/model/game.dart';
import 'package:snaphunt/model/player.dart';

class GameModel with ChangeNotifier {
  Game _game;
  Game get game => _game;

  bool _isHost;
  bool get isHost => _isHost;

  String _userId;
  String get userId => _userId;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  GameStatus _status = GameStatus.waiting;
  GameStatus get status => _status;

  bool _isGameStart = false;
  bool get isGameStart => _isGameStart;

  bool _canStartGame = false;
  bool get canStartGame => _canStartGame;

  StreamSubscription<DocumentSnapshot> gameStream;
  StreamSubscription<QuerySnapshot> playerStream;

  List<Player> _players = [];
  List<Player> get players => _players;

  final repository = Repository.instance;

  GameModel(this._game, this._isHost, this._userId);

  @override
  void addListener(listener) {
    initRoom();
    super.addListener(listener);
  }

  void initRoom() async {
    _isLoading = true;
    notifyListeners();

    if (_isHost) {
      String id = await repository.createRoom(_game);
      _game.id = id;
    }

    await joinRoom();

    _isLoading = false;
    notifyListeners();

    initStreams();
  }

  @override
  void dispose() {
    onDispose();
    super.dispose();
  }

  void initStreams() {
    gameStream = repository.gameSnapshot(_game.id).listen(gameStatusListener);
    playerStream = repository.playersSnapshot(_game.id).listen(playerListener);
  }

  void gameStatusListener(DocumentSnapshot snapshot) async {
    final status = snapshot.data['status'];
    if (status == 'cancelled') {
      _status = GameStatus.cancelled;
      notifyListeners();
    } else if (status == 'in_game') {
      _status = GameStatus.game;
      _game = Game.fromJson(snapshot.data);
      _game.id = snapshot.documentID;
      notifyListeners();
    }
  }

  void playerListener(QuerySnapshot snapshot) {
    snapshot.documentChanges.forEach((DocumentChange change) async {
      print(change.type);
      print(change.document.documentID);

      if (DocumentChangeType.added == change.type) {
        players.add(
            Player(user: await repository.getUser(change.document.documentID)));
      } else if (DocumentChangeType.removed == change.type) {
        if (change.document.documentID == _userId) {
          _status = GameStatus.kicked;
          notifyListeners();
          return;
        }

        players.removeWhere(
            (player) => player.user.uid == change.document.documentID);
      }
      checkCanStartGame();
      notifyListeners();
    });
  }

  void checkCanStartGame() {
    if (players.length >= 2) {
      _canStartGame = true;
    } else {
      _canStartGame = false;
    }
  }

  void onKickPlayer(String userId) {
    repository.kickPlayer(_game.id, userId);
  }

  void onDispose() {
    if (GameStatus.game != _status) {
      if (_isHost) {
        repository.cancelRoom(_game.id);
      } else {
        repository.leaveRoom(_game.id, _userId);
      }
    }

    gameStream.cancel();
    playerStream.cancel();
  }

  void onGameStart() {
    if (_canStartGame) {
      _isGameStart = true;
      repository.startGame(_game.id, numOfItems: _game.noOfItems);
    }
  }

  Future joinRoom() async {
    final playerCount = await repository.getGamePlayerCount(_game.id);

    if (playerCount >= _game.maxPlayers) {
      _status = GameStatus.full;
      return Future.value(null);
    }

    return repository.joinRoom(_game.id, _userId);
  }
}
