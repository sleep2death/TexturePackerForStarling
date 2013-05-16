package
{
	import flash.display.Bitmap;
	import flash.display.BitmapData;
	import flash.display.Shape;
	import flash.events.Event;
	import flash.geom.Matrix;
	import flash.geom.Point;
	import flash.geom.Rectangle;
	import flash.utils.Dictionary;
	
	/**
	 * ...
	 * @author Aspirin
	 */
	public class PackerSolution
	{
		private static var BDS:Vector.<BitmapData>;
		
		private static var KEYS:Vector.<String>;
		private static var FRAMES:Vector.<Rectangle>;
		
		public static var MAX_WIDTH:uint = 2048;
		public static var MAX_HEIGHT:uint = 2048;
		
		public static var PICTURES_NUM:uint = 0;
		
		private static var FAIL:Vector.<MaxRectsBinPack>;
		private static var SUCCESS:Vector.<MaxRectsBinPack>;
		
		public static var WIDTH:uint = 512;
		public static var HEIGHT:uint = 512;
		
		private static var W:Boolean = true;
		
		private static var CALL_BACK:Function;
		
		public static function findSolution(bds:Vector.<BitmapData>, keys:Vector.<String>, callBack:Function):void
		{
			WIDTH = 64;
			HEIGHT = 64;
			W = true;
			
			PICTURES_NUM = bds.length;
			//clone all bitmaps
			BDS = new Vector.<BitmapData>(PICTURES_NUM);
			KEYS = new Vector.<String>(PICTURES_NUM)
			
			for (var i:int = 0; i < PICTURES_NUM; i++)
			{
				BDS[i] = bds[i].clone();
				KEYS[i] = keys[i];
			}
			
			CALL_BACK = callBack;
			
			trimBitmaps();
			
			find();
		}
		
		static private function find():void
		{
			//trace("FIND " + WIDTH + " X " + HEIGHT );
			FAIL = new Vector.<MaxRectsBinPack>();
			SUCCESS = new Vector.<MaxRectsBinPack>();
			
			for (var method:int = 1; method <= 5; method++)
			{
				var rects:Vector.<Rectangle> = new Vector.<Rectangle>();
				
				for (var j:int = 0; j < PICTURES_NUM; j++)
				{
					rects.push(BDS[j].rect.clone());
				}
				
				var mrbp:MaxRectsBinPack = new MaxRectsBinPack(WIDTH, HEIGHT);
				mrbp.addEventListener("complete", onPackComplete);
				mrbp.insertBulk(rects, method);
			}
		}
		
		static private function onPackComplete(e:Event):void
		{
			//trace(PICTURES_NUM + "<>" + MaxRectsBinPack(e.target).usedRectangles.length + "<>" +  MaxRectsBinPack(e.target).freeRectangles.length);
			var rmbp:MaxRectsBinPack = e.target as MaxRectsBinPack;
			if (rmbp.usedRectangles.length < PICTURES_NUM)
			{
				FAIL.push(rmbp);
			}
			else
			{
				SUCCESS.push(rmbp);
			}
			
			if ((FAIL.length + SUCCESS.length) == 5)
			{
				if (FAIL.length == 5)
				{
					//trace("FAILED");
					findNext();
				}
				else
				{
					buildResult();
					//trace("SUCCESS");
				}
			}
		}
		
		static private function buildResult():void
		{
			var bd:BitmapData = new BitmapData(WIDTH, HEIGHT, true, 0);
			var xml:XML = <TextureAtlas/>
			var rmbp:MaxRectsBinPack = SUCCESS[0];
			for (var i:int = 0; i < PICTURES_NUM; i++)
			{
				var rect:Rectangle = rmbp.usedRectangles[i];
				//bd.copyPixels(BDS[index], new Rectangle(0, 0, BDS[index].width, BDS[index].height), new Point(rect.x, rect.y)); 
				for (var j:int = 0; j < PICTURES_NUM; j++)
				{
					if (BDS[j].rect.width == rect.width && BDS[j].rect.height == rect.height)
						break;
				}
				
				bd.copyPixels(BDS[j], BDS[j].rect, new Point(rect.x, rect.y));
				
				xml.appendChild(<SubTexture name={KEYS[j]} x={rect.x} y={rect.y} width={rect.width} height={rect.height} frameX={FRAMES[j].x} frameY={FRAMES[j].y} frameWidth={FRAMES[j].width} frameHeight={FRAMES[j].height}/>);
				
				BDS[j].dispose();
				BDS[j] = null;
				
				BDS.splice(j, 1);
				KEYS.splice(j, 1);
				FRAMES.splice(j, 1);
			}
			
			CALL_BACK.call(null, bd, xml);
		}
		
		static private function findNext():void
		{
			if (W)
			{
				if (WIDTH == MAX_WIDTH) {
					if (HEIGHT == MAX_HEIGHT) {
						CALL_BACK.call(null, null, null);
						return;
					}
				}else{
					WIDTH = getNextPowerOfTwo(WIDTH + 1);
					
				}
				W = false;
			}
			else
			{
				if (HEIGHT == MAX_HEIGHT) {
					if (WIDTH == MAX_WIDTH) {
						CALL_BACK.call(null, null, null);
						return;
					}
				}else {
					HEIGHT = getNextPowerOfTwo(HEIGHT + 1);
				}
				
				W = true;
			}
			
			find();
		}
		
		static private function getNextPowerOfTwo(number:int):int
		{
			if (number > 0 && (number & (number - 1)) == 0) // see: http://goo.gl/D9kPj
				return number;
			else
			{
				var result:int = 1;
				while (result < number)
					result <<= 1;
				return result;
			}
		}
		
		static private function sortBySize(a:BitmapData, b:BitmapData):int
		{
			var x:int = a.width * a.height;
			var y:int = b.width * b.height;
			
			if (x < y)
			{
				return 1;
			}
			else if (x > y)
			{
				return -1;
			}
			else
			{
				return 0;
			}
		}
		
		static private function trimBitmaps():void
		{
			FRAMES = new Vector.<Rectangle>(PICTURES_NUM);
			
			for (var i:int = 0; i < PICTURES_NUM; i++)
			{
				FRAMES[i] = trimTransparency(i);
			}
		}
		
		private static function trimTransparency(index : uint, colourChecker:uint = 0x00FF00):Rectangle
		{
			var source : BitmapData = BDS[index];
			
			var matrix:Matrix = new Matrix()
			matrix.tx = -source.rect.x;
			matrix.ty = -source.rect.y;
			
			var data:BitmapData = new BitmapData(source.width, source.height, true, 0);
			data.draw(source, matrix);
			var bounds:Rectangle = data.getColorBoundsRect(0xFFFFFFFF, 0x000000, false);
			data.dispose();
			
			var result : BitmapData = new BitmapData(bounds.width, bounds.height, true, 0);
			result.copyPixels(source, bounds, new Point(0, 0));
			
			bounds.x = -bounds.x;
			bounds.y = -bounds.y;
			bounds.width = source.width;
			bounds.height = source.height;
			
			BDS[index] = result;
			source.dispose();
			
			return bounds;
		}
	}

}