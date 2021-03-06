package {
    import flash.display.Sprite;
    [SWF(width="465", height="465", backgroundColor="0", frameRate="30")]
        public class Main extends Sprite {
        public function Main() { main = this; initializeFirst(); }
    }
}
// Game actor base class.
class Actor {
    public static var shapes:Vector.<PrimitiveShape>;
    public var shape:PrimitiveShape;
    public var sprite:PrimitiveSprite;
    public var pos:Vec = new Vec;
    public function Actor(type:int, size:Number) {
        if (shapes == null) shapes = new Vector.<PrimitiveShape>;
        for each (var s:PrimitiveShape in shapes) {
            if (s.type == type && s.width == size) { shape = s; break; }
        }
        if (!shape) { shape = new PrimitiveShape(type, size, size); shapes.push(shape); }
        sprite = new PrimitiveSprite(shape);
    }
}
/*----------------------------------------------------------------*/
// Initializers.
var score:int, ticks:int, flyAddTicks:int;
var scoreHistory:ScoreHistory = new ScoreHistory;
function initialize():void {
    startTitle();
}
function initializeTitle():void {
    removeAllSprites();
}
function initializeGame():void {
    removeAllSprites();
    lights = new Vector.<Light>(4);
    for (var i:int = 0; i < 4; i++) lights[i] = new Light(i);
    flies = new Vector.<Fly>;
    bomb = new Bomb;
    score = ticks = flyAddTicks = 0; 
}
function initalizeGameOver():void {
    scoreHistory.add(score);
}
// Update a game frame.
function updateGame():void {
    cg.printFromRight(String(score), SCREEN_WIDTH, 0);
    for each (var l:Light in lights) l.flyCount = 0;
    for (var i:int = 0; i < flies.length; i++) if (!flies[i].update()) {
        flies[i].sprite.remove(); flies.splice(i--, 1);
    }
    for each (l in lights) l.update();
    if (--flyAddTicks <= 0) {
        flies.push(new Fly);
        flyAddTicks = 30 - ticks * 0.01;
        if (flyAddTicks < 5) flyAddTicks = 5;
    }
    bomb.update();
    ticks++;
    for each (l in lights) if (l.power <= 0) startGameOver();
}
function updateTitle():void {
    scoreHistory.draw(SCREEN_WIDTH, 0);
    drawTitle("FLY LIGHT", new Array("<>^v"), new Array("LIGHT ON"), "Z");
}
function updateGameOver():void {
    scoreHistory.draw(SCREEN_HEIGHT, 0);
    cg.print("GAME OVER", 180, 200);
}
function get isStartButtonPressed():Boolean {
    return isButtonPressed;
}
// Lights.
var lights:Vector.<Light>;
class Light extends Actor {
    public static const SIZE:int = 32, LIGHT_HEIGHT:int = 16;
    public var index:int, isOn:Boolean;
    public var flyCount:int, power:Number = 1;
    public var rect:Rectangle = new Rectangle;
    public function Light(index:int) {
        super(PrimitiveShape.TRIANGLE, SIZE);
        this.index = index;
        var a:Number = index * PI / 2;
        sprite.angle = a;
        pos.x = pos.y = SCREEN_CENTER;
        pos.addAngle(a, SCREEN_CENTER - SIZE / 2);
        sprite.pos = pos;
    }
    public function update():void {
        switch (index) {
            case 0: isOn = isSPressed; break;
            case 1: isOn = isDPressed; break;
            case 2: isOn = isWPressed; break;
            case 3: isOn = isAPressed; break;
        }
        if (isOn) {
            var px:int, py:int, wx:int, wy:int;
            rect.x = pos.x; rect.y = pos.y;
            if (index == 0 || index == 2) {
                rect.width = 0; rect.height = LIGHT_HEIGHT;
                px = -LIGHT_HEIGHT; py = LIGHT_HEIGHT;
                if (index == 0) py *= -1;
                wx = LIGHT_HEIGHT * 2; wy = 0;
            } else {
                rect.width = LIGHT_HEIGHT; rect.height = 0;
                px = LIGHT_HEIGHT; py = -LIGHT_HEIGHT;
                if (index == 1) px *= -1;
                wx = 0; wy = LIGHT_HEIGHT * 2;
            }
            if (index == 0) rect.y += py;
            if (index == 1) rect.x += px;
            var c:int = 0xaa;
            for (var i:int = 0; i < 7 - flyCount; i++, c -= 0x11) {
                bd.fillRect(rect, c * 0x10000 + c * 0x100 + c);
                rect.x += px; rect.y += py;
                rect.width += wx; rect.height += wy;
            }
        }
        power = (6.0 - flyCount) / 6; if (power < 0) power = 0;
        sprite.alpha = power;
    }
}
// Flies.
var flies:Vector.<Fly> = new Vector.<Fly>;
class Fly extends Actor {
    public static const SIZE:Number = 10;
    public var angle:Number, angleTicks:Number, speed:Number;
    public var onLight:Light;
    public function Fly() {
        super(PrimitiveShape.CROSS, SIZE);
        pos.x = SCREEN_WIDTH * (0.3 + randn(0.4));
        pos.y = SCREEN_HEIGHT * (0.3 + randn(0.4));
        angle = randn(PI * 2);
        angleTicks = randn(1);
        speed = 5;
    }
    public function update():Boolean {
        var lp:Number = 0;
        for each (var l:Light in lights) {
            if (pos.distance(l.pos) < Light.SIZE) onLight = l;
            if (!l.isOn) continue;
            var oa:Number = abs(normalizeAnglePm(l.pos.angle(pos) - angle));
            if (oa < PI / 4) lp += l.power;
        }
        if (lp > 1) lp = 1;
        var avr:Number = 0.7;
        if (onLight) { speed += (0 - speed) * 0.5; onLight.flyCount++; }
        else if (lp > 0.1) { speed += (5 + 7 * lp - speed) * 0.5; avr /= 2; }
        else speed += (5 - speed) * 0.5;
        pos.addAngle(angle, speed);
        angle += sin(angleTicks * PI * 2) * avr;
        angleTicks += 0.05; if (angleTicks > 1) angleTicks -= 1;
        sprite.pos = pos;
        return isInScreen(pos);
    }
}
// Bomb.
var bomb:Bomb;
class Bomb extends Actor {
    public const SIZE:Number = 16;
    public var ticks:int, fs:int;
    public function Bomb() {
        super(PrimitiveShape.CIRCLE, SIZE);
        setPosition();
    }
    public function setPosition():void {
        pos.x = (randn(0.6) + 0.2) * SCREEN_WIDTH;
        pos.y = (randn(0.6) + 0.2) * SCREEN_HEIGHT;
        sprite.pos = pos;
        sprite.add();
        ticks = 90; fs = 1;
    }
    public function update():void {
        ticks--;
        if (ticks == 0) {
            sprite.remove();
            addParticlesRound(100, pos.x, pos.y, 2);
            for (var i:int = 0; i < 32; i++) {
                addParticleAngle(pos.x, pos.y, i * PI / 16, 2, 10);
            }
            return;
        } else if (ticks < 0) {
            var r:Number = -ticks * 2.5;
            for (i = 0; i < flies.length; i++) {
                var f:Fly = flies[i];
                if (pos.distance(f.pos) <= r) {
                    f.sprite.remove();
                    flies.splice(i--, 1);
                    addNumberBoard(fs, f.pos.x, f.pos.y);
                    score += fs++;
                }
            }
            if (ticks < -40) setPosition();
            return;
        }
        sprite.scale = sawtoothWave((90.0 - ticks) / 10) * 0.3 + 1;
        addParticles(2, pos.x - 5, pos.y - 15, -1, -5, 5 - ticks * 0.03, 0.9, 0.3);
    }
}
/*----------------------------------------------------------------*/
// Game lifecycle handlers.
import flash.display.*;
import flash.filters.*;
import flash.geom.*;
import flash.events.*;
import flash.text.*;
import flash.media.*;
import flash.net.*;
const SCREEN_WIDTH:int = 465;
const SCREEN_HEIGHT:int = 465;
const SCREEN_CENTER:int = 465 / 2;
var main:Main, bd:BitmapData;
var isMousePressed:Boolean, isMouseClicked:Boolean;
var keys:Vector.<Boolean> = new Vector.<Boolean>(256);
var isStartButtonReleased:Boolean;
// Initialize a bitmap, a font and events.
function initializeFirst():void {
    bd = new BitmapData(SCREEN_WIDTH, SCREEN_HEIGHT, false);
    bd.fillRect(bd.rect, 0);
    main.addChild(new Bitmap(bd));
    main.stage.addEventListener(MouseEvent.MOUSE_DOWN, function(e:Event):void { isMousePressed = true; });
    main.stage.addEventListener(MouseEvent.MOUSE_UP, function(e:Event):void { isMousePressed = false; });
    main.stage.addEventListener(MouseEvent.CLICK, function(e:Event):void { isMouseClicked = true; });
    main.stage.addEventListener(KeyboardEvent.KEY_DOWN, function(e:KeyboardEvent):void { keys[e.keyCode] = true; } );
    main.stage.addEventListener(KeyboardEvent.KEY_UP, function(e:KeyboardEvent):void { keys[e.keyCode] = false; } );
    loadFont();
}
function onFontLoaded():void {
    initializeBlurs();
    cg = new Cg;
    initialize();
    main.addEventListener(Event.ENTER_FRAME, updateFrame);
}
// Update a frame.
function updateFrame(event:Event):void {
    bd.fillRect(bd.rect, 0);
    bd.lock();
    if (isInGame) updateGame();
    else if (isTitle) updateTitle();
    else updateGameOver();
    updateParticles();
    updateNumberBoards();
    bd.unlock();
    if (isInGame && isEscPressed) startGameOver();
    if (gameOverTicks > 0) {
        gameOverTicks--;
        if (gameOverTicks == 0) startTitle();
    }
    if (isStartButtonPressed) {
        if (isStartButtonReleased) {
            isStartButtonReleased = false;
            if (!isInGame && gameOverTicks < GAME_OVER_DURATION - 30) startGame();
        }
    } else {
        isStartButtonReleased = true;
    }
}
// Handle a game state (Title/In game/Game over).
const GAME_OVER_DURATION:int = 180;
var gameOverTicks:int;
function startTitle():void {
    initializeTitle();
    gameOverTicks = 0;
}
function startGame():void {
    initializeGame();
    gameOverTicks = -1;
}
function startGameOver():void {
    if (!isInGame) return;
    initalizeGameOver();
    gameOverTicks = GAME_OVER_DURATION;
}
function get isInGame():Boolean {
    return (gameOverTicks < 0);
}
function get isTitle():Boolean {
    return (gameOverTicks == 0);
}
/*--------------------------------*/
// Particles.
var particles:Vector.<Particle> = new Vector.<Particle>;
class Particle {
    public static var gravity:Number = 0;
    public static var rect:Rectangle = new Rectangle;
    public static var drawIndex:int, color:int;
    public var pos:Vector3D = new Vector3D;
    public var vel:Vector3D = new Vector3D;
    public var size:Number, attenuation:Number;
    public function Particle(x:Number, y:Number, vx:Number, vy:Number, size:int, attenuation:Number) {
        pos.x = x; pos.y = y; vel.x = vx; vel.y = vy;
        this.size = size + 0.9;
        this.attenuation = attenuation;
    }
    public function update():Boolean {
        pos.x += vel.x; pos.y += vel.y;
        vel.y += gravity;
        size *= attenuation;
        return isInScreen(pos) && size >= 1.0;
    }
    public static function setDrawIndex(i:int):void {
        drawIndex = i;
        var bright:int = 0xff - i * 0x55;
        color = bright * 0x10000 + bright * 0x100 + bright;
    }
    public function draw():void {
        var sz:Number = size * (1.0 + drawIndex * 0.5);
        rect.x = pos.x - sz / 2; rect.y = pos.y - sz / 2;
        rect.width = rect.height = sz;
        bd.fillRect(rect, color);
    }
}
function updateParticles():void {
    var i:int;
    for (i = 0; i < particles.length; i++) if (!particles[i].update()) { particles.splice(i, 1); i--; }
    for (i = 2; i >= 0; i--) {
        Particle.setDrawIndex(i);
        for each (var p:Particle in particles) p.draw();
    }
}
function addParticle(x:Number, y:Number, vx:Number, vy:Number, size:int = 4, attenuation:Number = 0.95):void {
    particles.push(new Particle(x, y, vx, vy, size, attenuation));
}
function addParticleAngle(x:Number, y:Number, a:Number, s:Number, size:int = 4, attenuation:Number = 0.95, spreading:Number = 0.5):void {
    addParticle(x, y, sin(a) * s, cos(a) * s, size, attenuation);
}
function addParticles(n:int, x:Number, y:Number, vx:Number, vy:Number, size:int = 4, attenuation:Number = 0.95, spreading:Number = 0.5):void {
    var v:Number = (abs(vx) + abs(vy)) * spreading;
    for (var i:int = 0; i < n; i++) {
        particles.push(new Particle(x, y, vx + v * (-1 + randn(2)), vy + v * (-1 + randn(2)), size, attenuation));
    }
}
function addParticlesAngle(n:int, x:Number, y:Number, a:Number, s:Number, size:int = 4, attenuation:Number = 0.95, spreading:Number = 0.5):void {
    addParticles(n, x, y, sin(a) * s, cos(a) * s, size, attenuation, spreading);
}
function addParticlesRound(n:int, x:Number, y:Number, mv:Number, size:int = 4, attenuation:Number = 0.95):void {
    for (var i:int = 0; i < n; i++) {
        var a:Number = randn(PI * 2);
        var v:Number = mv * randn(1);
        particles.push(new Particle(x, y, sin(a) * v, cos(a) * v, size, attenuation));
    }
}
// Number boards.
var numberBoards:Vector.<NumberBoard> = new Vector.<NumberBoard>;
class NumberBoard {
    public var pos:Vector3D = new Vector3D;
    public var vel:Vector3D = new Vector3D;
    public var ticks:int, score:int, text:String;
    public function NumberBoard(score:int, x:Number, y:Number, ox:Number, oy:Number, ticks:int) {
        this.score = score; this.ticks = ticks; 
        pos.x = x; pos.y = y; vel.x = ox / ticks; vel.y = oy / ticks;
        text = String(score);
    }
    public function update():Boolean {
        pos.x += vel.x; pos.y += vel.y;
        cg.printFromCenter(text, pos.x, pos.y);
        return --ticks > 0;
    }
}
function updateNumberBoards():void {
    for (var i:int = 0; i < numberBoards.length; i++) if (!numberBoards[i].update()) { numberBoards.splice(i, 1); i--; }
}
function addNumberBoard(s:int, x:Number, y:Number, ox:Number = 0, oy:Number = -40, ticks:int = 30):void {
    numberBoards.push(new NumberBoard(s, x, y, ox, oy, ticks));
}
// Primitive shapes.
class PrimitiveShape {
    public static const CIRCLE:int = 0, BOX:int = 1, TRIANGLE:int = 2,
        CROSS:int = 3, BAR:int = 4, HUMAN:int = 5, CAR:int = 6,
        COUNT:int = 7;
    public static const POINTS:Array = [
        [-10, -10, 10, -10, 10, 10, -10, 10, -10, -10],
        [0, 10, -10, -10, 10, -10, 0, 10],
        [-10, -10, 10, 10, 99, 10, -10, -10, 10],
        [0, -10, 0, 10],
        [0, -10, 0, 0, -10, 10, 99, 0, 0, 10, 10, 99, -10, -3, 10, -3],
        [-7, 10, 7, 10, 99, 0, -10, 0, 10, 99, -10, -10, 10, -10],
    ];
    public var sbd:BitmapData, type:int, width:int, height:int;
    public var rect:Rectangle, point:Point = new Point;
    public function PrimitiveShape(type:int, width:int, height:int) {
        this.type = type; this.width = width; this.height = height;
        if (type == 0) {
            sbd = createBlurredBitmapData(function (g:Graphics):void {
                g.lineStyle(2, 0xffffff);
                g.drawEllipse(-width / 2, -height / 2, width, height);
            }, width, height);
        } else {
            var ps:Array = POINTS[type - 1];
            sbd = createBlurredBitmapData(function (g:Graphics):void {
                g.lineStyle(2, 0xffffff);
                var isMoveTo:Boolean = true, x:int, y:int;
                for (var i:int = 0; i < ps.length; i += 2) {
                    if (ps[i] == 99) { isMoveTo = true; i++; }
                    x = ps[i] * width / 20; y = ps[i + 1] * height / 20;
                    if (isMoveTo) { g.moveTo(x, y); isMoveTo = false; }
                    else g.lineTo(x, y);
                }
            }, width, height);
        }
        rect = new Rectangle(0, 0, width + BLUR_SIZE * 2, height + BLUR_SIZE * 2);
    }
    public function drawToSprite(s:Sprite):void {
        var b:Bitmap = new Bitmap(sbd);
        b.x = -width / 2 - BLUR_SIZE;
        b.y = -height / 2 - BLUR_SIZE;
        s.addChild(b);
    }
    public function draw(x:Number, y:Number):void {
        point.x = x - BLUR_SIZE; point.y = y - BLUR_SIZE;
        bd.copyPixels(sbd, rect, point);
    }
}
class PrimitiveSprite extends Sprite {
    public var isAdded:Boolean;
    public function PrimitiveSprite(shape:PrimitiveShape) {
        super();
        x = y = -999;
        shape.drawToSprite(this);
        add();
    }
    public function add():void {
        if (isAdded) return;
        main.addChild(this);
        isAdded = true;
    }
    public function remove():void {
        if (!isAdded) return;
        main.removeChild(this);
        isAdded = false;
    }
    public function changeShape(shape:PrimitiveShape):void {
        removeChildAt(0);
        shape.drawToSprite(this);
    }
    public function set pos(p:Vector3D):void {
        x = p.x; y = p.y;
    }
    public function set angle(a:Number):void {
        rotation = -a * 180 / PI;
    }
    public function set scale(v:Number):void {
        scaleX = scaleY = v;
    }
}
// Create a blurred bitmap data.
const BLUR_SIZE:int = 40, BLUR_SIZE_SKIP:int = 8;
var blurs:Vector.<BlurFilter>;
function initializeBlurs():void {
    blurs = new Vector.<BlurFilter>(BLUR_SIZE / BLUR_SIZE_SKIP);
    for (var i:int = BLUR_SIZE_SKIP; i < BLUR_SIZE; i += BLUR_SIZE_SKIP) {
        var blur:BlurFilter = new BlurFilter;
        blur.blurX = blur.blurY = i;
        blurs[i / BLUR_SIZE_SKIP] = blur;
    }
}
function createBlurredBitmapData(df:Function, w:Number, h:Number):BitmapData {
    var bd:BitmapData = new BitmapData(w + BLUR_SIZE * 2, h + BLUR_SIZE * 2, true, 0);
    var bs:Sprite = new Sprite;
    var s:Shape = new Shape;
    bs.addChild(s);
    s.x = w / 2 + BLUR_SIZE; s.y = h / 2 + BLUR_SIZE;
    var g:Graphics = s.graphics;
    df(g);
    bd.lock();
    for (var i:int = 0; i < BLUR_SIZE / BLUR_SIZE_SKIP; i++) {
        if (i > 0) bs.filters = [blurs[i]];
        bd.draw(bs);
    }
    bd.unlock();
    return bd;
}
// Character graphics plane.
var cg:Cg;
class Cg {
    public static const PIXEL_WIDTH:int = 14, PIXEL_HEIGHT:int = int(PIXEL_WIDTH * 1.4);
    public static const FONT_SIZE:int = 15;
    public static const STRINGS:String = "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789!@#$%^&*()_+-=[]\\{}|;':\",./?<>^v";
    private var bds:Vector.<BitmapData> = new Vector.<BitmapData>;
    private var keyBds:Vector.<BitmapData> = new Vector.<BitmapData>;
    private var rect:Rectangle = new Rectangle(0, 0, PIXEL_WIDTH * 1.4 + BLUR_SIZE * 2, PIXEL_HEIGHT * 1.4 + BLUR_SIZE * 2);
    public function Cg() {
        for (var i:int = 0; i < STRINGS.length; i++) {
            var bd:BitmapData;
            bd = createCharacterBitmapData(STRINGS.charAt(i));
            bds.push(bd);
            bd = createCharacterBitmapData(STRINGS.charAt(i), true);
            keyBds.push(bd);
        }
    }
    public function print(s:String, x:Number, y:Number, isKey:Boolean = false, fromRight:Boolean = false, fromCenter:Boolean = false):void {
        var p:Point = new Point, cbd:BitmapData, px:Number;
        px = x - BLUR_SIZE; p.y = y - BLUR_SIZE;
        var spacing:Number = PIXEL_WIDTH * 0.8;
        if (isKey) spacing *= 2;
        if (fromRight) px -= (s.length + 1) * spacing;
        else if (fromCenter) px -= (s.length + 1) / 2 * spacing;
        for (var i:int = 0; i < s.length; i++, px += spacing) {
            var c:int = STRINGS.indexOf(s.charAt(i));
            if (c >= 0) {
                if (isKey) cbd = keyBds[c];
                else cbd = bds[c];
                p.x = px; bd.copyPixels(cbd, rect, p);
            }
        }
    }
    public function printKeys(s:String, x:Number, y:Number):void {
        print(s, x, y, true);
    }
    public function printFromRight(s:String, x:Number, y:Number):void {
        print(s, x, y, false, true);
    }
    public function printFromCenter(s:String, x:Number, y:Number):void {
        print(s, x, y, false, false, true);
    }
}
const CHARACTER_COLOR:int = 0xffffff;
function createCharacterBitmapData(c:String, isKey:Boolean = false):BitmapData {
    var bd:BitmapData = new BitmapData(Cg.PIXEL_WIDTH * 1.4 + BLUR_SIZE * 2, Cg.PIXEL_HEIGHT * 1.4 + BLUR_SIZE * 2, true, 0);
    var bs:Sprite = new Sprite, g:Graphics;
    if (isKey && (c == '<' || c == '>' || c == "^" || c == "v")) {
        var s:Shape = new Shape;
        g = s.graphics;
        g.lineStyle(2, 0xffffff);
        g.moveTo(0, -Cg.PIXEL_WIDTH * 0.3);
        g.lineTo(0, Cg.PIXEL_WIDTH * 0.3);
        g.lineTo(-Cg.PIXEL_WIDTH * 0.2, Cg.PIXEL_WIDTH * 0.1);
        g.moveTo(0, Cg.PIXEL_WIDTH * 0.3);
        g.lineTo(Cg.PIXEL_WIDTH * 0.2, Cg.PIXEL_WIDTH * 0.1);
        s.blendMode = BlendMode.ADD;
        bs.addChild(s);
        s.x = Cg.PIXEL_WIDTH * 0.7 + BLUR_SIZE;
        s.y = Cg.PIXEL_HEIGHT * 0.7 + BLUR_SIZE;
        switch (c) {
            case "<": s.rotation = 90; break;
            case "^": s.rotation = 180; break;
            case ">": s.rotation = 270; break;
        }
    } else {
        var t:TextField = createTextField(0, 0, Cg.FONT_SIZE, bd.rect.width, bd.rect.height, CHARACTER_COLOR);
        t.text = c;
        var tm:TextLineMetrics = t.getLineMetrics(0);
        var ofs:Number = Number(Cg.PIXEL_WIDTH * 1.4 - tm.width) / 2;
        var tbd:BitmapData = new BitmapData(Cg.PIXEL_WIDTH * 1.4, Cg.PIXEL_HEIGHT * 1.4, true, 0);
        tbd.draw(t);
        var b:Bitmap = new Bitmap(tbd);
        b.blendMode = BlendMode.ADD;
        bs.addChild(b);
        b.x = ofs + BLUR_SIZE; b.y = BLUR_SIZE;
    }
    if (isKey) {
        g = bs.graphics;
        g.lineStyle(2, 0xffffff);
        g.moveTo(BLUR_SIZE, BLUR_SIZE);
        g.lineTo(BLUR_SIZE + Cg.PIXEL_WIDTH * 1.4, BLUR_SIZE);
        g.lineTo(BLUR_SIZE + Cg.PIXEL_WIDTH * 1.4, BLUR_SIZE + Cg.PIXEL_HEIGHT * 1.4);
        g.lineTo(BLUR_SIZE, BLUR_SIZE + Cg.PIXEL_HEIGHT * 1.4);
        g.lineTo(BLUR_SIZE, BLUR_SIZE);
    }
    bd.lock();
    for (var i:int = 0; i < BLUR_SIZE / BLUR_SIZE_SKIP; i++) {
        if (i > 0) bs.filters = [blurs[i]];
        bd.draw(bs);
    }
    bd.unlock();
    return bd;
}
// Score history.
class ScoreHistory {
    public var scores:Vector.<int> = new Vector.<int>(10);
    public var endIndex:int;
    public function add(s:int):void {
        for (var i:int = scores.length - 1; i > 0; i--) scores[i] = scores[i - 1];
        scores[0] = s;
        if (endIndex < scores.length) endIndex++;
    }
    public function draw(x:int, sy:int):void {
        var y:Number = sy;
        for (var i:int = 0; i < endIndex; i++) {
            cg.printFromRight(String(scores[i]), x, y);
            if (i == 0) y += Cg.FONT_SIZE * 2;
            else y += Cg.FONT_SIZE * 1.2;
        }
    }
}
// Vector3D with utility functions.
class Vec extends Vector3D {
    public function distance(p:Vector3D):Number {
        return getLength(x - p.x, y - p.y);
    }
    public function angle(p:Vector3D):Number {
        return atan2(x - p.x, y - p.y);
    }
    public function addAngle(a:Number, s:Number):void {
        x += sin(a) * s; y += cos(a) * s;
    }
}
/*--------------------------------*/
// Math utility functions.
var sin:Function = Math.sin, cos:Function = Math.cos, atan2:Function = Math.atan2; 
var sqrt:Function = Math.sqrt, abs:Function = Math.abs;
var PI:Number = Math.PI;
function randi(n:int):int {
    return Math.random() * n;
}
function randn(n:Number):Number {
    return Math.random() * n;
}
function getLength(x:Number, y:Number):Number {
    return sqrt(x * x + y * y);
}
function normalizeAngle(a:Number):Number {
    if (a >= PI * 2) return a % (PI * 2);
    else if (a < 0) return PI * 2 + a % (PI * 2);
    return a;
}
function normalizeAnglePm(a:Number):Number {
    a = normalizeAngle(a);
    if (a > PI) return a - PI * 2;
    return a;
}
function aim(a:Number, tagetAngle:Number, maxRotation:Number):Number {
    var oa:Number = normalizeAnglePm(tagetAngle - a);
    if (oa > maxRotation) oa = maxRotation;
    else if (oa < -maxRotation) oa = -maxRotation;
    return a + oa;
}
function sign(v:Number):int {
    return (v > 0) ? 1 : ((v < 0) ? -1 : 0);
}
function sawtoothWave(x:Number, increment:Number = 0.5):Number {
    return (x % 1) + int(x) * increment;
}
// Operation utility functions.
var wasdWay:Vector3D = new Vector3D, ijklWay:Vector3D = new Vector3D;
function getWasdWay(m:Number = 1):Vector3D {
    wasdWay.x = wasdWay.y = 0;
    if (isWPressed) wasdWay.y -= 1;
    if (isAPressed) wasdWay.x -= 1;
    if (isSPressed) wasdWay.y += 1;
    if (isDPressed) wasdWay.x += 1;
    if (wasdWay.x != 0 && wasdWay.y != 0) {
        wasdWay.x *= 0.7; wasdWay.y *= 0.7;
    }
    wasdWay.x *= m; wasdWay.y *= m;
    return wasdWay;
}
function get isWPressed():Boolean { return keys[0x26] || keys[0x57]; }
function get isAPressed():Boolean { return keys[0x25] || keys[0x41]; }
function get isSPressed():Boolean { return keys[0x28] || keys[0x53]; }
function get isDPressed():Boolean { return keys[0x27] || keys[0x44]; }
function getIjklWay(m:Number = 1):Vector3D {
    ijklWay.x = ijklWay.y = 0;
    if (isIPressed) ijklWay.y -= 1;
    if (isJPressed) ijklWay.x -= 1;
    if (isKPressed) ijklWay.y += 1;
    if (isLPressed) ijklWay.x += 1;
    if (ijklWay.x != 0 && ijklWay.y != 0) {
        ijklWay.x *= 0.7; ijklWay.y *= 0.7;
    }
    ijklWay.x *= m; ijklWay.y *= m;
    return ijklWay;
}
function get isIPressed():Boolean { return keys[0x49]; }
function get isJPressed():Boolean { return keys[0x4a]; }
function get isKPressed():Boolean { return keys[0x4b]; }
function get isLPressed():Boolean { return keys[0x4c]; }
function get isButtonPressed():Boolean {
    return isButton1Pressed || isButton2Pressed;
}
function get isButton1Pressed():Boolean {
    return keys[0x5a] || keys[0xbe] || keys[0x20];
}
function get isButton2Pressed():Boolean {
    return keys[0x58] || keys[0xbf];
}
function get isEscPressed():Boolean {
    return keys[0x1b];
}
// Screen utility functions.
function isInScreen(p:Vector3D):Boolean {
    return (p.x >= 0 && p.x <= SCREEN_WIDTH && p.y >= 0 && p.y <= SCREEN_HEIGHT);
}
function setInScreen(p:Vector3D):void {
    if (p.x < 0) p.x = 0;
    else if (p.x > SCREEN_WIDTH) p.x = SCREEN_WIDTH;
    if (p.y < 0) p.y = 0;
    else if (p.y > SCREEN_HEIGHT) p.y = SCREEN_HEIGHT;
}
function removeAllSprites():void {
    while (main.numChildren > 1) main.removeChildAt(1);
}
function drawTitle(title:String, buttonStrs:Array, operationStrs:Array, startButton:String):void {
    cg.print(title, 100, 100);
    var y:int = 200;
    for (var i:int = 0; i < buttonStrs.length; i++, y += 30) {
        cg.printKeys(buttonStrs[i], 120, y);
        cg.print(operationStrs[i], 240, y);
    }
    y += 10;
    cg.printKeys(startButton, 120, y);
    cg.print("START", 240, y);
}
// Text utility functions.
import net.wonderfl.utils.FontLoader;
const DEFAULT_FONT_NAME:String = "_typewriter";
const FONT_NAME:String = "Bebas";
function loadFont():void {
    var loader:FontLoader = new FontLoader();
    loader.addEventListener(Event.COMPLETE, onFontLoaded);
    loader.load(FONT_NAME);
}
function createTextField(x:int, y:int, size:int, width:int, height:int, color:int, hasSpacing:Boolean = true):TextField {
    var fm:TextFormat = new TextFormat(FONT_NAME), fi:TextField = new TextField;
    fm.size = size; fm.color = color; fm.leftMargin = 0; fm.bold = false;
    if (hasSpacing) fm.letterSpacing = 3;
    fi.defaultTextFormat = fm;
    if (FONT_NAME != DEFAULT_FONT_NAME) fi.embedFonts = true;
    fi.x = x; fi.y = y; fi.width = width; fi.height = height; fi.selectable = false;
    return fi;
}
function drawStringToSprite(sp:Sprite, s:String, x:int, y:int, size:int, color:int, hasSpacing:Boolean = true):void {
    var t:TextField = createTextField(x, y, size, size * s.length, size * 1.5, color, hasSpacing);
    t.text = s;
    sp.addChild(t);
}