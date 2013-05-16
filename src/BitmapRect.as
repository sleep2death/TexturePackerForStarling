package  
{
	import flash.display.BitmapData;
	import flash.geom.Rectangle;
	
	/**
	 * ...
	 * @author Aspirin
	 */
	public class BitmapRect extends Rectangle 
	{
		public var bd : BitmapData;
		public var key : String;
		
		public function BitmapRect(key : String, bd : BitmapData) 
		{
			this.key = key;
			this.bd = bd;
			super(0, 0, bd.rect.width, bd.rect.height);
		}
		
	}

}