package {
    import flash.display.Sprite;
    [SWF(width="465", height="465", backgroundColor="0", frameRate="60")]
    public class Main extends Sprite {
        public function Main() { initializeFirst(this); }
    }
}
import flash.display.*;
import flash.geom.*;
import flash.filters.*;
import flash.events.*;
import flash.text.*;
import flash.utils.getTimer;
import org.si.sion.*;
var main:Main;
var bd:BitmapData;
var blurBd:BitmapData;
var baseSprite:Sprite = new Sprite;
var backgroundColor:uint = 0;
function initializeFirst(main:Main):void {
    this.main = main;
    screen = new Screen;
    bd = new BitmapData(screen.size.x, screen.size.y, true, 0);
    blurBd = new BitmapData(screen.size.x, screen.size.y, false, 0);
    baseSprite.addChild(new Bitmap(blurBd));
    main.addChild(baseSprite);
    mouse = new Mouse;
    key = new Key;
    letter = new Letter;
    initialize();
    if (DEBUG) beginGame();
    else setScoreRecordViewer();
    main.addEventListener(Event.ACTIVATE, onActivated);
    main.addEventListener(Event.DEACTIVATE, onDectivated);
    main.addEventListener(Event.ENTER_FRAME, updateFrame);
}
var fadeFilter:ColorMatrixFilter = new ColorMatrixFilter([
    1, 0, 0, 0, 0,  0, 1, 0, 0, 0,  0, 0, 1, 0, 0,  0, 0, 0, 0.8, 0]);
var blurFilter10:BlurFilter = new BlurFilter(10, 10);
var blurFilter20:BlurFilter = new BlurFilter(20, 20);
var zeroPoint:Point = new Point;
function updateFrame(event:Event):void {
    bd.lock();
    bd.fillRect(bd.rect, backgroundColor);
    updateGame();
    bd.unlock();
    blurBd.lock();
    blurBd.applyFilter(blurBd, blurBd.rect, zeroPoint, fadeFilter);
    blurBd.copyPixels(bd, bd.rect, zeroPoint, null, null, true);
    blurBd.applyFilter(blurBd, blurBd.rect, zeroPoint, blurFilter20);
    blurBd.copyPixels(bd, bd.rect, zeroPoint, null, null, true);
    blurBd.applyFilter(blurBd, blurBd.rect, zeroPoint, blurFilter10);
    blurBd.copyPixels(bd, bd.rect, zeroPoint, null, null, true);
    blurBd.unlock();    
}
// ---- Math utils. ----
var sin:Function = Math.sin, cos:Function = Math.cos, atan2:Function = Math.atan2; 
var sqrt:Function = Math.sqrt, abs:Function = Math.abs;
var PI:Number = Math.PI, PI2:Number = PI * 2, HPI:Number = PI / 2;
function getLength(x:Number, y:Number):Number {
    return sqrt(x * x + y * y);
}
function clamp(v:Number, min:Number, max:Number):Number {
    if (v > max) return max;
    else if (v < min) return min;
    return v;
}
function normalizeAngle(v:Number):Number {
    var r:Number = v % PI2;
    if (r < -PI) r += PI2;
    else if (r > PI) r -= PI2;
    return r;
}
function aimAngle(angle:Number, targetAngle:Number, angleVel:Number):Number {
    var oa:Number = normalizeAngle(targetAngle - angle);
    var r:Number;
    if (oa > angleVel) r = angle + angleVel;
    else if (oa < -angleVel) r = angle - angleVel;
    else r = targetAngle;
    return normalizeAngle(r);
}
class Xy extends Vector3D {
    public function Xy(x:Number = 0, y:Number = 0) {
        super(x, y);
    }
    public function distance(pos:Xy):Number {
        return getLength(pos.x - x, pos.y - y);
    }
    public function angle(pos:Xy):Number {
        return atan2(pos.x - x, pos.y - y);
    }
    public function addAngle(angle:Number, speed:Number):void {
        x += sin(angle) * speed;
        y += cos(angle) * speed;
    }
    public function rotate(angle:Number):void {
        var px:Number = x;
        x = -x * cos(angle) + y * sin(angle);
        y = px * sin(angle) + y * cos(angle);
    }
    public function set xy(v:Xy):void {
        x = v.x; y = v.y;
    }
    public function set s(v:Number):void {
        x = y = v;
    }
    public function get way():Number {
        return atan2(x, y);
    }
}
var random:Random = new Random;
class Random {
    private var x:int, y:int, z:int, w:int;
    function Random(v:int = int.MIN_VALUE):void {
        var sv:int;
        if (v == int.MIN_VALUE) sv = getTimer();
        else sv = v;
        x = sv = 1812433253 * (sv ^ (sv >> 30));
        y = sv = 1812433253 * (sv ^ (sv >> 30)) + 1;
        z = sv = 1812433253 * (sv ^ (sv >> 30)) + 2;
        w = sv = 1812433253 * (sv ^ (sv >> 30)) + 3;
    }
    public function n(v:Number = 1, s:Number = 0):Number {
        return value * v + s;
    }
    public function i(v:int, s:int = 0):int {
        return n(v, s);
    }
    public function sx(v:Number = 1, s:Number = 0):Number {
        return n(v, s) * screen.size.x;
    }
    public function sy(v:Number = 1, s:Number = 0):Number {
        return n(v, s) * screen.size.y;
    }
    public function pm():int {
        return i(2) * 2 - 1;
    }
    public function pmn(v:Number = 1):Number {
        return random.n(v) * pm();
    }
    private function get value():Number {
        var t:int = x ^ (x << 11);
        x = y; y = z; z = w;
        w = (w ^ (w >> 19)) ^ (t ^ (t >> 8));
        return Number(w) / int.MAX_VALUE;
    }    
}
class Actor {
    public var pos:Xy = new Xy;
    public var vel:Xy = new Xy;
    public var size:Xy = new Xy;
    public var angle:Number = 0, speed:Number = 0;
    public static function updateAll(s:*):void {
        for (var i:int = 0; i < s.length; i++) if (!s[i].update()) s.splice(i--, 1);
    }
    public static function checkHit(ca:*, s:*, callHit:Boolean = false):Boolean {
        var hf:Boolean = false;
        for each (var a:* in s) {
            if (ca == a) continue;
            if (abs(ca.pos.x - a.pos.x) < (ca.size.x + a.size.x) / 2 &&
            abs(ca.pos.y - a.pos.y) < (ca.size.y + a.size.y) / 2) {
                if (callHit) a.hit(ca);
                hf = true;
            }
        }
        return hf;
    }
    public static const HIT_X:int = 1;
    public static const HIT_Y:int = 2;
    private static var pPos:Xy = new Xy;
    public static function checkHitVel(ca:*, s:*):int {
        var r:int;
        pPos.xy = ca.pos;
        ca.pos.x += ca.vel.x;
        if (checkHit(ca, s)) r |= HIT_X;
        ca.pos.x = pPos.x;
        ca.pos.y += ca.vel.y;
        if (checkHit(ca, s)) r |= HIT_Y;
        ca.pos.y = pPos.y;
        return r;
    }
}
// ---- UI utils. ----
var mouse:Mouse;
class Mouse {
    public var pos:Xy = new Xy;
    public var isPressing:Boolean;
    public function Mouse() {
        baseSprite.addEventListener(MouseEvent.MOUSE_MOVE, onMoved);
        baseSprite.addEventListener(MouseEvent.MOUSE_DOWN, onPressed);
        baseSprite.addEventListener(MouseEvent.MOUSE_UP, onReleased);
        baseSprite.addEventListener(Event.MOUSE_LEAVE, onReleased);
    }
    private function onMoved(e:MouseEvent):void {
        pos.x = e.stageX; pos.y = e.stageY;
    }
    private function onPressed(e:MouseEvent):void {
        isPressing = true;
        onMoved(e);
    }
    private function onReleased(e:Event):void {
        isPressing = false;
    }
}
var key:Key;
class Key {
    public var s:Vector.<Boolean> = new Vector.<Boolean>(256);
    public function Key() {
        main.stage.addEventListener(KeyboardEvent.KEY_DOWN, onPressed);
        main.stage.addEventListener(KeyboardEvent.KEY_UP, onReleased);
    }
    private function onPressed(e:KeyboardEvent):void {
        s[e.keyCode] = true;
    }
    private function onReleased(e:KeyboardEvent):void {
        s[e.keyCode] = false;
    }
    public function get isWPressed():Boolean {
        return s[0x26] || s[0x57];
    }
    public function get isAPressed():Boolean {
        return s[0x25] || s[0x41];
    }
    public function get isSPressed():Boolean {
        return s[0x28] || s[0x53];
    }
    public function get isDPressed():Boolean {
        return s[0x27] || s[0x44];
    }
    private var stickXy:Xy = new Xy;
    public function get stick():Xy {
        stickXy.s = 0;
        if (isWPressed) stickXy.y -= 1;
        if (isAPressed) stickXy.x -= 1;
        if (isSPressed) stickXy.y += 1;
        if (isDPressed) stickXy.x += 1;
        if (stickXy.x != 0 && stickXy.y != 0) stickXy.scaleBy(0.7);
        return stickXy;
    }
    public function get isButtonPressed():Boolean {
        return isButton1Pressed || isButton2Pressed;
    }
    public function get isButton1Pressed():Boolean {
        return s[0x5a] || s[0xbe] || s[0x20];
    }
    public function get isButton2Pressed():Boolean {
        return s[0x58] || s[0xbf];
    }
}
var screen:Screen;
class Screen {
    public var size:Xy;
    public var center:Xy;
    function Screen() {
        size = new Xy(main.stage.stageWidth, main.stage.stageHeight);
        center = new Xy(size.x / 2, size.y / 2);
    }
    public function isIn(p:Xy, spacing:Number = 0):Boolean {
        return (p.x >= -spacing && p.x <= size.x + spacing && 
            p.y >= -spacing && p.y <= size.y + spacing);
    }
}
// ---- Graphics and sound utils. ----
var fRect:Rectangle = new Rectangle;
function fillRect(x:int, y:int, width:int, height:int, color:uint):void {
    fRect.x = x - int(width / 2);
    fRect.y = y - int(height / 2);
    fRect.width = width;
    fRect.height = height;
    bd.fillRect(fRect, color);
}
class Color {
    private static const LEVEL:int = 5;
    private static const LEVEL_VALUE:int = 50;
    private static const MAX_VALUE:int = LEVEL * LEVEL_VALUE;
    public static var transparent:Color = new Color(-1);
    public static var black:Color = new Color(0, 0, 0);
    public static var red:Color = new Color(MAX_VALUE, 0, 0);
    public static var green:Color = new Color(0, MAX_VALUE, 0);
    public static var blue:Color = new Color(0, 0, MAX_VALUE);
    public static var yellow:Color = new Color(MAX_VALUE, MAX_VALUE, 0);
    public static var magenta:Color = new Color(MAX_VALUE, 0, MAX_VALUE);
    public static var cyan:Color = new Color(0, MAX_VALUE, MAX_VALUE);
    public static var white:Color = new Color(MAX_VALUE, MAX_VALUE, MAX_VALUE);
    public var r:int, g:int, b:int;
    public function Color(r:int = 0, g:int = 0, b:int = 0) {
        this.r = r; this.g = g; this.b = b;
    }
    public function get i():uint {
        return 0xff000000 + r * 0x10000 + g * 0x100 + b;
    }
    public function set rgb(c:Color):void {
        r = c.r; g = c.g; b = c.b;
    }
    private static var blinkColor:Color = new Color;
    public function get blink():Color {
        changeValueColor(
            blinkColor, random.i(128, -64), random.i(128, -64), random.i(128, -64));
        return blinkColor;
    }
    public function get br():Color {
        return changeValue(LEVEL_VALUE, LEVEL_VALUE, LEVEL_VALUE);
    }
    public function get dr():Color {
        return changeValue(-LEVEL_VALUE, -LEVEL_VALUE, -LEVEL_VALUE);
    }
    public function get rz():Color {
        return changeValue(LEVEL_VALUE, -LEVEL_VALUE, -LEVEL_VALUE);
    }
    public function get gz():Color {
        return changeValue(-LEVEL_VALUE, LEVEL_VALUE, -LEVEL_VALUE);
    }
    public function get bz():Color {
        return changeValue(-LEVEL_VALUE, -LEVEL_VALUE, LEVEL_VALUE);
    }
    private function changeValue(rv:int, gv:int, bv:int):Color {
        var changedColor:Color = new Color;
        changeValueColor(changedColor, rv, gv, bv);
        return changedColor;
    }
    private function changeValueColor(color:Color, rv:int, gv:int, bv:int):void {
        color.rgb = this;
        color.r += rv; color.g += gv; color.b += bv;
        color.normalize();
    }
    private function normalize():void {
        r = clamp(r, 0, MAX_VALUE);
        g = clamp(g, 0, MAX_VALUE);
        b = clamp(b, 0, MAX_VALUE);
    }
}
class DotShape {
    public static const BASE_SCALE:Number = 3;
    private static var rPos:Xy = new Xy;
    private static var rect:Rectangle = new Rectangle;
    private var dots:Vector.<OffsetColor> = new Vector.<OffsetColor>;
    private var color:Color = Color.transparent;
    private var colorSpot:Color = Color.transparent;
    private var spotThreshold:Number = 0.3;
    private var xAngleVel:Number = 0;
    private var yAngleVel:Number = 0;
    private var xyAngleVel:Number = 0;
    private var offset:Xy = new Xy;
    public function c(c:Color, cs:Color = null):DotShape {
        color = c;
        if (cs) colorSpot = cs;
        return this;
    }
    public function st(v:Number):DotShape {
        spotThreshold = v;
        return this;
    }
    public function sa(x:Number = 0, y:Number = 0, xy:Number = 0):DotShape {
        xAngleVel = x;
        yAngleVel = y;
        xyAngleVel = xy;
        return this;
    }
    public function o(x:Number = 0, y:Number = 0):DotShape {
        offset.x = x; offset.y = y;
        return this;
    }
    public function fr(width:int, height:int, isDrawingEdge:Boolean = false):DotShape {
        var ox:int = -width / 2, oy:int = -height / 2;
        for (var y:int = 0; y < height; y++) {
            for (var x:int = 0; x < width; x++) {
                if (!isDrawingEdge ||
                    x == 0 || x == width - 1 || y == 0 || y == height - 1) fd(x + ox, y + oy);
            }
        }
        return this;
    }
    public function fc(radius:Number, isDrawingEdge:Boolean = false):DotShape {
        var d:int = 3 - radius * 2;
        var y:int = radius;
        for (var x:int = 0; x <= y; x++) {
            if (isDrawingEdge) {
                setCircleDotsEdge(x, y);
                setCircleDotsEdge(y, x);
            } else {
                setCircleDots(x, y);
                setCircleDots(y, x);
            }
            if (d < 0) {
                d += 6 + x * 4;
            } else {
                d += 10 + x * 4 - y * 4;
                y--;
            }
        }
        return this;
    }
    public function fd(x:Number, y:Number):DotShape {
        var ca:Number =
            Math.cos(x * xAngleVel) * Math.cos(y * yAngleVel) * Math.cos((x + y) * xyAngleVel);
        var c:Color;
        if (Math.abs(ca) < spotThreshold) c = colorSpot;
        else c = color;
        if (c.r < 0) return this;
        var d:OffsetColor = new OffsetColor;
        d.offset.x = x + offset.x;
        d.offset.y = y + offset.y;
        d.color = c.i;
        dots.push(d);
        return this;
    }
    private function setCircleDots(x:int, y:int):void {
        setXLine(-x, x, y);
        setXLine(-x, x, -y);
    }
    private function setXLine(xb:int, xe:int, y:int):void {
        for (var x:int = xb; x <= xe; x++) fd(x, y);
    }
    private function setCircleDotsEdge(x:int, y:int):void {
        fd(-x, y); fd(x, y);
        fd(-x, -y); fd(x, -y);
    }
    public function draw(
    pos:Xy, angle:Number = 0, scale:Number = BASE_SCALE, rectScale:int = -1):void {
        if (rectScale > 0) rect.width = rect.height = rectScale;
        else rect.width = rect.height = scale;
        var o:int = scale / 2;
        for each (var d:OffsetColor in dots) {
            rPos.xy = d.offset;
            rPos.scaleBy(scale);
            if (angle != 0) rPos.rotate(angle);
            rect.x = int(pos.x + rPos.x) - o;
            rect.y = int(pos.y + rPos.y) - o;
            bd.fillRect(rect, d.color);
        }
    }
}
class OffsetColor {
    public var offset:Xy = new Xy;
    public var color:uint;
}
var letter:Letter;
class Letter {
    private var shapes:Vector.<DotShape> = new Vector.<DotShape>;
    private var charToIndex:Vector.<int> = new Vector.<int>;
    function Letter() {
        const COUNT:int = 53;
        var patterns:Array = [
        0x4644AAA4, 0x6F2496E4, 0xF5646949, 0x167871F4, 0x2489F697, 0xE9669696, 0x79F99668,
        0x91967979, 0x1F799976, 0x1171FF17, 0xF99ED196, 0xEE444E99, 0x53592544, 0xF9F11119,
        0x9DDB9999, 0x79769996, 0x7ED99611, 0x861E9979, 0x994444E7, 0x46699699, 0x6996FD99,
        0xF4469999, 0x2226F248, 0x44644466, 0xF0044E, 0x12448, 0x640444F0, 0x4049,
        0x44040404, 0x4444, 0x5E40000A, 0x424F4244, 0x2F244E54, 0x4];
        var d:int, lp:int, pIndex:int;
        for (var i:int = 0; i < COUNT; i++) {
            var shape:DotShape = new DotShape;
            shape.c(Color.white);
            for (var j:int = 0; j < 5; j++) {
                for (var k:int = 0; k < 4; k++) {
                    if (--d <= 0) {
                        lp = patterns[pIndex++];
                        d = 32;
                    }
                    if (lp & 1 > 0) shape.fd(k, j);
                    lp >>= 1;
                }
            }
            shapes.push(shape);
        }
        var charCodes:Array = [
        91, 93, 43, 45, 47, 95, 33, 63, 46, 58, 124, 39, 34, 117, 114, 100, 108];
        for (var c:int = 0; c < 128; c++) {
            var li:int = -1;
            if (c >= 48 && c < 58) {
                li = c - 48;
            } else if (c >= 65 && c <= 90) {
                li = c - 65 + 10;
            } else {
                var lic:int = 36;
                for each (var cc:int in charCodes) {
                    if (cc == c) {
                        li = lic;
                        break;
                    }
                    lic++;
                }
            }
            charToIndex.push(li);
        }
    }
    private var tPos:Xy = new Xy;
    public function draw(text:String, x:Number, y:Number, isFromRight:Boolean = false):void {
        tPos.x = x;
        if (isFromRight) tPos.x -= text.length * 10;
        else tPos.x -= text.length * 10 / 2;
        tPos.y = y;
        for (var i:int = 0; i < text.length; i++) {
            var c:int = text.charCodeAt(i);
            var li:int = charToIndex[c];
            if (li >= 0) shapes[li].draw(tPos, 0, 2);
            tPos.x += 10;
        }
    }
}
class Message extends Actor {
    public static var s:Vector.<Message> = new Vector.<Message>;
    private static var shownMessages:Vector.<String> = new Vector.<String>;
    public static function addOnce(
    text:String, pos:Xy, vx:Number = 0, vy:Number = 0, ticks:int = 240):Message {
        if (shownMessages.indexOf(text) >= 0) return null;
        shownMessages.push(text);
        return add(text, pos, vx, vy, ticks);
    }
    public static function add(
    text:String, pos:Xy, vx:Number = 0, vy:Number = 0, ticks:int = 60):Message {
        var m:Message = new Message;
        m.text = text;
        m.pos.xy = pos;
        m.vel.x = vx / ticks; m.vel.y = vy / ticks;
        m.ticks = ticks;
        s.push(m);
        return m;
    }
    public var text:String, ticks:int;
    public function update():Boolean {
        pos.incrementBy(vel);
        letter.draw(text, pos.x, pos.y);
        return --ticks > 0;
    }
}
class Particle extends Actor {
    public static var s:Vector.<Particle> = new Vector.<Particle>;
    public static function add(
    pos:Xy, color:Color, size:Number, count:Number, speed:Number, ticks:Number = 60,
    angle:Number = 0, angleWidth:Number = Math.PI * 2):void {
        for (var i:int = 0; i < count; i++) {
            var pt:Particle = new Particle;
            pt.color = color;
            pt.targetSize = size;
            pt.pos.xy = pos;
            pt.vel.addAngle(
                angle + random.n(angleWidth / 2) * random.pm(), speed * random.n(1, 0.5));
            pt.ticks = ticks * random.n(1, 0.5);
            s.push(pt);
        }
    }
    private var ticks:int;
    private var color:Color;
    private var scale:Number = 1;
    private var targetSize:Number;
    private var isExpand:Boolean = true;
    public function update():Boolean {
        pos.incrementBy(vel);
        vel.scaleBy(0.98);
        if (isExpand) {
            scale *= 1.5;
            if (scale > targetSize) isExpand = false;
        } else {
            scale *= 0.95;
        }
        fillRect(pos.x, pos.y, scale, scale, color.blink.i);
        return --ticks > 0;
    }
}
class Se {
    public static const MAJOR:int = 0;
    public static const MINOR:int = 1;
    public static const NOISE:int = 2;
    public static const NOISE_SCALE:int = 3;
    private static var tones:Array = [
        ["c", "c+", "d", "d+", "e", "f", "f+", "g", "g+", "a", "a+", "b"],
        ["c", "d", "e", "g", "a"],
        ["c", "d-", "e-", "g-", "a-"]];
    public static var s:Vector.<Se> = new Vector.<Se>;
    private static var driver:SiONDriver = new SiONDriver;
    private static var isStarting:Boolean;
    private var data:SiONData;
    private var isPlaying:Boolean;
    private var mml:String;
    private var type:int;
    private var tone:Number = 0;
    public function t(v:int):Se {
        type = v;
        if (!mml) mml = "";
        else mml += ";";
        var voices:Array = [1, 1, 9, 10];
        mml += "%1@" + voices[v] + "l64";
        return this;
    }
    public function m(step:Number, time:int, start:Number = -1):Se {
        if (start >= 0) tone = start;
        for (var i:int = 0; i < time; i++) {
            tone = clamp(tone, 0, 1);
            switch (type) {
                case MAJOR:
                case MINOR:
                    var ti:int = tone * 40;
                    var o:int = ti / 5 + 2;
                    mml += "o" + o + tones[type + 1][ti % 5];
                    break;
                case NOISE:
                case NOISE_SCALE:
                    ti = tone * 15;
                    if (ti < 4) mml += "o5" + tones[0][3 - ti];
                    else mml += "o4" + tones[0][15 - ti];
                    break;
            }
            tone += step / time;
        }
        return this;
    }
    public function r(v:int = 1):Se {
        for (var i:int = 0; i < v; i++) mml += "r";
        return this;
    }
    public function v(v:int = 16):Se {
        mml += "v" + v;
        return this;
    }
    public function c():Se {
        isStarting = false;
        data = driver.compile(mml);
        driver.volume = 0;
        driver.play();
        s.push(this);
        return this;
    }
    public function play():void {
        if (!isInGame) return;
        isPlaying = true;
    }
    public function update():void {
        if (!isPlaying) return;
        if (!isStarting) {
            driver.volume = 0.9;
            isStarting = true;
        }
        driver.sequenceOn(data, null, 0, 0, 0);
        isPlaying = false;
    }
}
// ---- Game state controller. ----
var score:int, ticks:int;
var isInGame:Boolean;
var isPaused:Boolean;
var wasClicked:Boolean, wasReleased:Boolean;
var titleTicks:int;
function beginGame():void {
    isInGame = true;
    score = 0;
    ticks = 0;
    closeScoreForms();
    random = new Random;
    Particle.s = new Vector.<Particle>;
    initialize();
}
function endGame():Boolean {
    if (!isInGame) return false;
    isInGame = false;
    wasClicked = wasReleased = false;
    ticks = 0;
    recordScore(score);
    setScoreRecordViewer();
    titleTicks = 10;
    return true;
}
function updateGame():void {
    if (!isPaused) update();
    Actor.updateAll(Particle.s);
    for each (var s:Se in Se.s) s.update();
    letter.draw(String(score), screen.size.x, 2, true);
    ticks++;
    if (!isInGame) {
        letter.draw(TITLE, screen.size.x * 0.8, screen.center.y - 20);
        letter.draw("CLICK", screen.size.x * 0.8, screen.center.y + 8);
        letter.draw("TO", screen.size.x * 0.8, screen.center.y + 20);
        letter.draw("START", screen.size.x * 0.8, screen.center.y + 32);
        if (mouse.isPressing) {
            if (wasReleased) wasClicked = true;
        } else {
            if (wasClicked) beginGame();
            if (--titleTicks <= 0) wasReleased = true;
        }
    }
    if (isPaused) {
        letter.draw("PAUSED", screen.center.x, screen.center.y - 8);
        letter.draw("CLICK TO RESUME", screen.center.x, screen.center.y + 8);
    }
    Actor.updateAll(Message.s);
}
function onActivated(e:Event):void {
    isPaused = false;
}
function onDectivated(e:Event):void {
    if (isInGame) isPaused = true;
}
/*
function setScoreRecordViewer():void { }
function recordScore(s:int):void { }
function closeScoreForms():void { }
/*/
import net.wonderfl.score.basic.BasicScoreForm;
import net.wonderfl.score.basic.BasicScoreRecordViewer;
var scoreRecordViewer:BasicScoreRecordViewer;
var scoreForm:BasicScoreForm;
function setScoreRecordViewer():void {
    scoreRecordViewer = new BasicScoreRecordViewer(main, 5, 220, "SCORE RANKING", 50);
}
function recordScore(score:int):void {
    scoreForm = new BasicScoreForm(main, 5, 5, score);
    scoreForm.onCloseClick = function():void {
        closeScoreForms();
        setScoreRecordViewer();
    }
}
function closeScoreForms():void {
    if (scoreRecordViewer) {
        main.removeChild(scoreRecordViewer);
        scoreRecordViewer = null;
    }
    if (scoreForm) {
        main.removeChild(scoreForm);
        scoreForm = null;
    }
}
//*/
// ---- Game main logic. ----
const TITLE:String = "SEA VS ISLAND"
const DEBUG:Boolean = false;
const GRID_COUNT:int = 31;
const GRID_DOT:int = 15;
var grid:Vector.<Vector.<Number>>;
var gridShapes:Vector.<DotShape>;
var shipAddTicks:int;
function initialize():void {
    if (!grid) initGrid();
    for (var y:int = 0; y < GRID_COUNT; y++) {
        for (var x:int = 0; x < GRID_COUNT; x++) {
            grid[x][y] = 0;
        }
    }
    setGridHeight();
    Ship.s = new Vector.<Ship>;
    shipAddTicks = 0;
}
function initGrid():void {
    grid = new Vector.<Vector.<Number>>;
    for (var y:int = 0; y < GRID_COUNT; y++) {
        var gx:Vector.<Number> = new Vector.<Number>;
        for (var x:int = 0; x < GRID_COUNT; x++) {
            gx.push(0);
        }
        grid.push(gx);
    }
    gridShapes = new Vector.<DotShape>;
    for (var i:int = -10; i <= 10; i++) {
        var c:Color;
        if (i < 0) c = new Color(240 + i * 24, 240 + i * 24, 255);
        else c = new Color(200 - i * 20, 128 + i * 12, 32);
        gridShapes.push(new DotShape().c(c).fd(0, 0));
    }
}
function update():void {
    for (var y:int = 0; y < GRID_COUNT; y++) {
        for (var x:int = 0; x < GRID_COUNT; x++) {
            var uv:Number =
            (GRID_COUNT * 0.45 - Math.max(abs(x - GRID_COUNT / 2), abs(y - GRID_COUNT / 2))) *
            0.003;
            if (uv <= 0) continue;
            grid[x][y] += random.n(uv, uv);
            if (grid[x][y] > 10) grid[x][y] = 10;
        }
    }
    if (isInGame) {
        if (ticks == 0) Message.addOnce("MOUSE: DIG", new Xy(100, 100));
        var gx:int = clamp(mouse.pos.x / GRID_DOT, 0, GRID_COUNT - 1);
        var gy:int = clamp(mouse.pos.y / GRID_DOT, 0, GRID_COUNT - 1);
        downGrid(gx, gy);
    }
    drawGrid();
    if (isInGame) {
        if (--shipAddTicks <= 0) {
            Ship.s.push(new Ship);
            shipAddTicks = 300 / (1 + sqrt(ticks * 0.0003));
        }
        Actor.updateAll(Ship.s);
    }
}
var gPos:Xy = new Xy;
function drawGrid():void {
    for (var y:int = 0; y < GRID_COUNT; y++) {
        for (var x:int = 0; x < GRID_COUNT; x++) {
            gPos.x = x * GRID_DOT + GRID_DOT / 2;
            gPos.y = y * GRID_DOT + GRID_DOT / 2 - grid[x][y] * 2;
            gridShapes[int(grid[x][y]) + 10].draw(gPos, 0, GRID_DOT - 6);
        }
    }
}
function setGridHeight():void {
    for (var i:int = 0; i < 30; i++) {
        addGridHeight(-random.i(4, 2), random.i(GRID_COUNT), random.i(GRID_COUNT));
    }
    for (i = 0; i < 30; i++) {
        addGridHeight(random.i(4, 2),
            random.i(GRID_COUNT / 2, GRID_COUNT / 4), random.i(GRID_COUNT / 2, GRID_COUNT / 4));
    }
}
function addGridHeight(h:int, x:int, y:int):void {
    var ah:int = abs(h);
    for (var ox:int = -(ah - 1); ox <= ah - 1; ox++) {
        for (var oy:int = -(ah - 1); oy <= ah - 1; oy++) {
            var gh:int = ah - Math.min(abs(ox), abs(oy));
            if (h < 0) gh *= -1;
            var gx:int = normalizeGridPos(x + ox);
            var gy:int = normalizeGridPos(y + oy);
            grid[gx][gy] = clamp(grid[gx][gy] + gh, -10, 10);
        }
    }
}
function downGrid(cx:int, cy:int):void {
    for (var ox:int = -5; ox <= 5; ox++) {
        for (var oy:int = -5; oy <= 5; oy++) {
            var x:int = cx + ox;
            var y:int = cy + oy;
            if (x < 0 || x >= GRID_COUNT || y < 0 || y >= GRID_COUNT) continue;
            var h:Number = grid[x][y];
            h -= 0.5 / (sqrt(abs(ox) + abs(oy)) + 1);
            if (h < -10) h = -10;
            grid[x][y] = h;
        }
    }
}
function normalizeGridPos(v:Number, s:Number = GRID_COUNT):Number {
    if (v < 0) return v + s;
    else if (v >= s) return v - s;
    return v;
}
class Ship extends Actor {
    public static var s:Vector.<Ship>;
    private static var shape:DotShape = new DotShape().
        c(Color.red.dr, Color.magenta.dr).sa(1, 2, 3).fr(5, 7).o(0, 3).fc(2).
        c(Color.red, Color.magenta).sa(1, 2, 3).o().fr(5, 7, true).o(0, 3).fc(2, true);
    private static var sailSe:Se = new Se().
        t(Se.MINOR).v(11).m(-0.3, 3, 0.5).c();
    private static var scoreSe:Se = new Se().
        t(Se.MAJOR).v(12).m(0, 2, 0.7).r().m(0, 2, 0.7).r().m(0, 2, 0.7).c();
    private static var dstSe:Se = new Se().
        t(Se.NOISE_SCALE).m( -0.5, 5, 0.7).m( -0.5, 7, 0.5).c();
    private static var sPos:Xy = new Xy;
    private static var tPos:Xy = new Xy;
    private var pPos:Xy = new Xy;
    private var addScore:int;
    private var seTicks:int;
    function Ship() {
        for (var i:int = 0; i < 50; i++) {
            pos.x = random.i(GRID_COUNT);
            pos.y = random.i(2) * (GRID_COUNT - 1);
            if (random.pm() > 0) {
                var tx:Number = pos.x;
                pos.x = pos.y;
                pos.y = tx;
            }
            if (grid[int(pos.x)][int(pos.y)] < -3) break; 
        }
        tPos.x = random.n(GRID_COUNT * 0.6, GRID_COUNT * 0.2);
        tPos.y = random.n(GRID_COUNT * 0.6, GRID_COUNT * 0.2);
        angle = pos.angle(tPos);
        speed = random.n(0.07, 0.03);
        vel.addAngle(angle, speed);
    }
    public function update():Boolean {
        pPos.xy = pos;
        pos.incrementBy(vel);
        sPos.xy = pos;
        sPos.scaleBy(GRID_DOT);
        if (pos.x < 0 || pos.x >= GRID_COUNT || pos.y < 0 || pos.y >= GRID_COUNT) {
            var ta:Number = sPos.angle(screen.center);
            tPos.s = 0;
            tPos.addAngle(ta, 50);
            Message.add("+" + addScore, sPos, tPos.x, tPos.y);
            score += addScore;
            scoreSe.play();
            return false;
        }
        if (grid[int(pos.x)][int(pos.y)] >= 0) {
            pos.xy = pPos;
            addScore -= 2;
            if (addScore < 0) addScore = 0;
        } else {
            addScore++;
            if (seTicks++ % 73 == 0) sailSe.play();
        }
        shape.draw(sPos, angle);
        letter.draw(String(addScore), sPos.x, sPos.y - 10);
        Particle.add(sPos, Color.blue.br.br, 5, 1, speed, 30, angle + PI, 0.3);
        if (grid[int(pos.x)][int(pos.y)] >= 1) {
            Particle.add(sPos, Color.red.gz.gz, 50, 50, 5);
            addGridHeight(5, pos.x, pos.y);
            dstSe.play();
            endGame();
            return false;
        }
        return true;
    }
}