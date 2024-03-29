import 'dart:math' as math;
import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flame/game.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

enum GameState { setup, ready, play, gameover, victory }

enum Direction { up, down, left, right }

class Position {
  int x = 0;
  int y = 0;

  Position(this.x, this.y);

  @override
  String toString() => 'x: $x, y: $y';
}

class SnakeGame extends FlameGame with HasKeyboardHandlerComponents {
  late Main main;

  @override
  void onLoad() {
    main = Main();
    add(main);

    super.onLoad();
  }
}

class Main extends PositionComponent with KeyboardHandler, HasGameRef<SnakeGame> {
  GameState state = GameState.setup;
  int gridSize = 16;

  Position food = Position(0, 0);
  List<Position> snake = [];
  Direction direction = Direction.down;
  bool changedDirectionThisTurn = false;

  late Timer snakeUpdateTimer;
  double snakeUpdateInterval = 1;

  @override
  void render(Canvas canvas) {
    var cellSize = gameRef.canvasSize.x / gridSize;
    var epsilon = 0.1;

    // Draw Food
    var x = food.x.toDouble() * cellSize;
    var y = food.y.toDouble() * cellSize;
    var paint = Paint();
    paint.color = Color.fromARGB(255, 76, 206, 137);

    // Rect tileRect = Rect.fromLTRB(x, y, x + cellSize, y + cellSize);
    var r = RRect.fromLTRBR(x, y, x + cellSize, y + cellSize, Radius.circular(2));
    canvas.drawRRect(r, paint);

    // Draw snake
    for (var i = 0; i < snake.length; i++) {
      var cell = snake[i];

      // Don't draw a cell if it leaves the grid.
      var outOfBounds = positionIsOutOfBounds(cell);
      if (outOfBounds) continue;

      var x = cell.x.toDouble() * cellSize;
      var y = cell.y.toDouble() * cellSize;
      var paint = Paint();
      // paint.color = i == 0 && game.debugMode ? Colors.yellow : Colors .blue; //draw the head a different color than the rest of the body.
      paint.color = Color(0xff7f7fff);

      // Epsilon is a small amount that is subtracted from the cell size so that multiple cells do not overlap and keeps them from z fighting.
      var r = RRect.fromLTRBR(x, y, x + cellSize - epsilon, y + cellSize - epsilon, Radius.circular(2));
      canvas.drawRRect(r, paint);
    }

    // Draw UI.
    var textPaint = TextPaint(style: TextStyle(fontSize: 35, fontFamily: 'Inconsolata', color: Colors.white));
    var centerPosition = Vector2(gameRef.canvasSize.x / 2, gameRef.canvasSize.y / 2);
    var bottomCenterPosition = Vector2(gameRef.canvasSize.x / 2, gameRef.canvasSize.y);
    var topCenterPosition = Vector2(gameRef.canvasSize.x / 2, 0);

    if (state == GameState.victory) {
      textPaint.render(canvas, 'You Win!', centerPosition, anchor: Anchor.center);
      textPaint.render(canvas, "Press 'R' to restart", bottomCenterPosition, anchor: Anchor.bottomCenter);
    } else if (state == GameState.gameover) {
      textPaint.render(canvas, 'Game Over.', centerPosition, anchor: Anchor.center);
      textPaint.render(canvas, "Press 'R' to restart", bottomCenterPosition, anchor: Anchor.bottomCenter);
    } else if (state == GameState.ready) {
      textPaint.render(canvas, 'SNAKE GAME', topCenterPosition, anchor: Anchor.topCenter);
      textPaint.render(canvas, "Press 'Space' to start.", bottomCenterPosition, anchor: Anchor.bottomCenter);
      textPaint.render(canvas, 'Use arrow keys to play.', centerPosition, anchor: Anchor.center);
    }
  }

  void placeNewFood() {
    // Check if there are no places to place the food. This is the victory condition, ie, the snake occupies the entire grid.
    var totalGridCells = gridSize * gridSize;
    var totalSnakeCells = snake.length;
    if (totalSnakeCells == totalGridCells) {
      //game is won
      state = GameState.victory;
    }

    while (true) {
      var random = math.Random();
      food.x = random.nextInt(gridSize);
      food.y = random.nextInt(gridSize);

      // check food is not in the same position as the snake.
      var inSnake = false;
      for (var position in snake) {
        if (food.x == position.x && food.y == position.y) inSnake = true;
      }
      if (!inSnake) break;
    }
  }

  void updateSnake() {
    if (kDebugMode) print('current snake: $snake, length: ${snake.length}, direction: ${direction.name}.');

    // update the snake's position
    var snakeHead = snake.first;
    var newHead = nextPosition(snakeHead, direction);
    snake.insert(0, newHead);
    snake.removeLast();

    changedDirectionThisTurn = false;
  }

  @override
  bool onKeyEvent(KeyEvent event, Set<LogicalKeyboardKey> keysPressed) {
    if (event is! KeyDownEvent) return false; // we only care about key down events.

    // we have different keyboard behaviours depending on the current game's state.
    switch (state) {
      case GameState.setup:
        // We don't take any input during setup phase.
        return false;

      case GameState.ready:
        switch (event.logicalKey) {
          case LogicalKeyboardKey.space:
            state = GameState.play;
            game.paused = false;
            return true;
        }
        return false;

      case GameState.play:
        switch (event.logicalKey) {
          case LogicalKeyboardKey.arrowUp:
            if (direction != Direction.down && !changedDirectionThisTurn) {
              direction = Direction.up;
              changedDirectionThisTurn = true;
              return true;
            }
          case LogicalKeyboardKey.arrowRight:
            if (direction != Direction.left && !changedDirectionThisTurn) {
              direction = Direction.right;
              changedDirectionThisTurn = true;
              return true;
            }
          case LogicalKeyboardKey.arrowDown:
            if (direction != Direction.up && !changedDirectionThisTurn) {
              direction = Direction.down;
              changedDirectionThisTurn = true;
              return true;
            }
          case LogicalKeyboardKey.arrowLeft:
            if (direction != Direction.right && !changedDirectionThisTurn) {
              direction = Direction.left;
              changedDirectionThisTurn = true;
              return true;
            }
          case LogicalKeyboardKey.keyR:
            if (kDebugMode) print('restarting game');
            state = GameState.setup;
            return true;
          case LogicalKeyboardKey.space:
            if (game.debugMode) {
              if (game.paused) {
                if (kDebugMode) print('Unpausing the game.');
                game.paused = false;
              } else {
                if (kDebugMode) print('Resuming the game.');
                game.paused = true;
              }
              return true;
            }
            return false;

          case LogicalKeyboardKey.keyV:
            if (game.debugMode) {
              state = GameState.victory;
              if (kDebugMode) print('Setting Victory.');
              return true;
            }
            return false;
        }
        return false;

      case GameState.gameover:
        switch (event.logicalKey) {
          case LogicalKeyboardKey.keyR:
            if (kDebugMode) print('Restarting Game.');
            state = GameState.setup;
            return true;
        }
        return false;

      case GameState.victory:
        switch (event.logicalKey) {
          case LogicalKeyboardKey.keyR:
            if (kDebugMode) print('Restarting Game.');
            state = GameState.setup;
            return true;
        }
        return false;
    }
  }

  @override
  void update(double dt) {
    switch (state) {
      case GameState.setup:

        // set snake's initial position
        snake = [Position(0, 2), Position(0, 1)];
        direction = Direction.down;
        snakeUpdateTimer = Timer(0.15, onTick: updateSnake, repeat: true);

        placeNewFood();

        state = GameState.ready;
        break;

      case GameState.ready:
        if (kDebugMode) print('press space to begin.');
        break;

      case GameState.play:
        assert(snake.length >= 2, 'snake should be at least two long');

        snakeUpdateTimer.update(dt); // runs the snake update code

        var head = snake.first;
        var next = nextPosition(head, direction);

        // check if snake eats food
        if (head.x == food.x && head.y == food.y) {
          snake.add(next);
          // food = Position(-1, -1);
          placeNewFood();
        }

        // check if snake is eating itself or out of bounds.
        for (var i = 1; i < snake.length; i++) {
          var body = snake[i];
          if (body.x == head.x && body.y == head.y) {
            if (kDebugMode) print('snake ate itself!');
            state = GameState.gameover;
          }
        }

        var outOfBounds = positionIsOutOfBounds(head);
        if (outOfBounds) {
          if (kDebugMode) print('Snake left the grid.');
          state = GameState.gameover;
        }

        break;

      case GameState.gameover:
        // display a game over text
        break;
      case GameState.victory:
        // display a victory text
        break;
    }

    super.update(dt);
  }

  Position nextPosition(Position current, Direction d) {
    return switch (direction) {
      Direction.up => Position(current.x, current.y - 1),
      Direction.down => Position(current.x, current.y + 1),
      Direction.left => Position(current.x - 1, current.y),
      Direction.right => Position(current.x + 1, current.y)
    };
  }

  bool positionIsOutOfBounds(Position p) {
    return p.x < 0 || p.y < 0 || p.x >= gridSize || p.y >= gridSize;
  }
}
