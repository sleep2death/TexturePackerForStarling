package
{
	import com.bit101.components.CheckBox;
	import com.bit101.components.ComboBox;
	import com.bit101.components.Label;
	import com.bit101.components.PushButton;
	import flash.display.Bitmap;
	import flash.display.BitmapData;
	import flash.display.Loader;
	import flash.display.LoaderInfo;
	import flash.display.Shape;
	import flash.display.Sprite;
	import flash.display.StageAlign;
	import flash.display.StageScaleMode;
	import flash.events.Event;
	import flash.events.MouseEvent;
	import flash.filesystem.File;
	import flash.filesystem.FileMode;
	import flash.filesystem.FileStream;
	import flash.geom.Point;
	import flash.geom.Rectangle;
	import flash.net.URLLoader;
	import flash.net.URLRequest;
	import flash.text.TextField;
	import flash.utils.ByteArray;
	import flash.utils.Dictionary;
	import PNGEncoder2;
	
	import starling.core.Starling;
	
	/**
	 * ...
	 * @author Aspirin
	 */
	public class Main extends Sprite
	{
		
		public function Main():void
		{
			this.addEventListener(Event.ADDED_TO_STAGE, onAdded);
		}
		
		private function onAdded(e:Event):void
		{
			removeEventListener(Event.ADDED_TO_STAGE, onAdded);
			this.stage.scaleMode = StageScaleMode.NO_SCALE;
			this.stage.align = StageAlign.TOP_LEFT;
			
			w = stage.stageWidth;
			h = stage.stageHeight;
			
			addChildren();
			
			this.stage.addEventListener(Event.RESIZE, onResize);
		}
		
		private function onResize(e:Event):void
		{
			w = stage.stageWidth;
			h = stage.stageHeight;
			
			status.y = h - 15;
		}
		
		private var w:uint;
		private var h:uint;
		
		private static const STATE_EMPTY:int = 0;
		private static const STATE_LOADING:int = 1;
		private static const STATE_GENERATING:int = 2;
		private static const STATE_FINISHED:int = 3;
		private static const STATE_FAILED:int = -1;
		
		private var state:uint = STATE_EMPTY;
		
		[Embed(source="../res/icons/open.png")]
		private static const FOLDER_ICON:Class;
		private static var folder_icon:Bitmap = new FOLDER_ICON() as Bitmap;
		
		[Embed(source="../res/icons/save.png")]
		private static const EXPORT_ICON:Class;
		private static var export_icon:Bitmap = new EXPORT_ICON() as Bitmap;
		
		private var browseBtn:PushButton;
		private var label:Label;
		private var widthComboBox:ComboBox;
		private var heightComboBox:ComboBox;
		private var recursiveCheckBox:CheckBox;
		private var trimCheckBox:CheckBox;
		private var showRegionsCheckBox:CheckBox;
		private var exportBtn:PushButton;
		
		private var resultBitmap:Bitmap;
		private var resultXML:XML;
		private var regionDes:Sprite;
		private var status:Label;
		
		private function addChildren():void
		{
			browseBtn = new PushButton(this, 5, 5, "Add Folder", browseFolder);
			browseBtn.addIcon(folder_icon);
			
			label = new Label(this, browseBtn.x + browseBtn.width + 15, 5, "Max Size:");
			
			widthComboBox = new ComboBox(this, label.x + label.width + 5, 5, "512", [{label: "128"}, {label: "256"}, {label: "512"}, {label: "1024"}, {label: "2048"}]);
			heightComboBox = new ComboBox(this, widthComboBox.x + widthComboBox.width + 5, 5, "512", [{label: "128"}, {label: "256"}, {label: "512"}, {label: "1024"}, {label: "2048"}]);
			
			widthComboBox.selectedIndex = 3;
			heightComboBox.selectedIndex = 3;
			
			widthComboBox.addEventListener(Event.SELECT, findSolution);
			heightComboBox.addEventListener(Event.SELECT, findSolution);
			
			recursiveCheckBox = new CheckBox(this, heightComboBox.x + heightComboBox.width + 5, 10, "Recursive");
			recursiveCheckBox.selected = true;
			//trimCheckBox = new CheckBox(this, recursiveCheckBox.x + recursiveCheckBox.width + 5, 10, "Trim", refresh);
			//showRegionsCheckBox = new CheckBox(this, trimCheckBox.x + trimCheckBox.width + 5, 10, "Regions", drawRegions);
			//recursiveCheckBox.selected = trimCheckBox.selected = showRegionsCheckBox.selected = true;
			
			exportBtn = new PushButton(this, recursiveCheckBox.x + recursiveCheckBox.width + 5, 5, "Export", export);
			exportBtn.addIcon(export_icon);
			exportBtn.enabled = false;
			
			regionDes = new Sprite();
			
			resultBitmap = new Bitmap();
			regionDes.x = resultBitmap.x = 5;
			regionDes.y = resultBitmap.y = 30;
			addChild(resultBitmap);
			addChild(regionDes);
			
			status = new Label(this, 5, h - 15, "ATP 1.0");
		}
		
		private function setState(value:int):void
		{
			if (state != value)
			{
				switch (value)
				{
					case STATE_LOADING: 
					case STATE_GENERATING:
						exportBtn.enabled = browseBtn.enabled = widthComboBox.enabled = heightComboBox.enabled = recursiveCheckBox.enabled = exportBtn.enabled = false;
						status.text = "Generating...";
						break;
					case STATE_FINISHED: 
						exportBtn.enabled = browseBtn.enabled = widthComboBox.enabled = heightComboBox.enabled = recursiveCheckBox.enabled = exportBtn.enabled = true;
						status.text = "Done";
						break;
					case STATE_FAILED:
						exportBtn.enabled = browseBtn.enabled = widthComboBox.enabled = heightComboBox.enabled = recursiveCheckBox.enabled = true;
						exportBtn.enabled = false;
						status.text = "FAILED!!! Enlarge the max texture size";
						break;
				}
				
				trace(status.text);
				
				state = value;
			}
		}
		
		private var folder:File = new File();
		
		private function browseFolder(evt:MouseEvent):void
		{
			folder.addEventListener(Event.SELECT, onFolderSelected);
			folder.browseForDirectory("Please select the target folder...");
		}
		
		private var bitmapURLs:Vector.<String>;
		
		private function onFolderSelected(e:Event):void
		{
			folder.removeEventListener(Event.SELECT, onFolderSelected);
			
			bitmapURLs = new Vector.<String>();
			
			setState(STATE_LOADING);
			findPictures(folder);
			
			refresh();
		}
		
		private function findPictures(folderFile:File):void
		{
			if (folderFile.isDirectory)
			{
				for each (var f:File in folderFile.getDirectoryListing())
				{
					if (f.extension && (f.extension.toLowerCase() == "png"))
					{
						bitmapURLs.push(f.url);
					}
					else if (f.isDirectory && recursiveCheckBox.selected)
					{
						findPictures(f);
					}
				}
			}
		}
		
		private function refresh():void
		{
			loadPictures();
		}
		
		private var bitmaps:Vector.<BitmapData>;
		private var keys:Vector.<String>;
		
		private function loadPictures():void
		{
			var len:uint = bitmapURLs.length;
			
			bitmaps = new Vector.<BitmapData>();
			keys = new Vector.<String>();
			
			for (var i:int = 0; i < len; i++)
			{
				var ldr:Loader = new Loader();
				var req:URLRequest = new URLRequest(bitmapURLs[i]);
				ldr.contentLoaderInfo.addEventListener(Event.COMPLETE, onBitmapLoaded);
				ldr.load(req);
			}
		}
		
		private function onBitmapLoaded(evt:Event):void
		{
			var info:LoaderInfo = evt.target as LoaderInfo;
			var reg:RegExp = /(\w+)\.([\w]{3})/gi;
			var name:String = reg.exec(info.url)[1];
			
			bitmaps.push(Bitmap(info.content).bitmapData);
			keys.push(name);
			
			if (bitmaps.length == bitmapURLs.length)
			{
				findSolution();
			}
		}
		
		private function findSolution(evt:Event = null):void
		{
			var maxWidth:uint = int(widthComboBox.selectedItem.label);
			var maxHeight:uint = int(heightComboBox.selectedItem.label);
			
			PackerSolution.MAX_HEIGHT = maxHeight;
			PackerSolution.MAX_WIDTH = maxWidth;
			
			setState(STATE_GENERATING)
			PackerSolution.findSolution(bitmaps, keys, finded);
		}
		
		
		private function finded(bd:BitmapData, xml:XML):void
		{
			if (!bd) {
				setState(STATE_FAILED);
				return;
			}
			
			regionDes.graphics.clear();
			regionDes.graphics.lineStyle(0, 0xCCCCCC, 1);
			regionDes.graphics.drawRect(0, 0, bd.width, bd.height);
			
			if (resultBitmap.bitmapData) {
				resultBitmap.bitmapData.dispose();
				resultBitmap.bitmapData = null;
			}
			
			resultBitmap.bitmapData = bd;
			resultXML = xml;
			
			setState(STATE_FINISHED);
		}
		
		private function export(evt : Event) : void
		{
			folder.addEventListener(Event.SELECT, saveFile);
			folder.browseForSave("Save As");
		}
		
		private function saveFile(e:Event):void 
		{
			folder.removeEventListener(Event.SELECT, saveFile);
			
			if (folder.exists && folder.isDirectory==false) {
				folder = folder.parent.resolvePath(folder.name.split(".")[0]);
			}
			
			var f1 : File = folder.resolvePath(folder.url + ".xml");
			
			var fs : FileStream = new FileStream();
			fs.open(f1, FileMode.WRITE);
			fs.writeUTFBytes(resultXML.toXMLString());
			fs.close();
			
			var ba : ByteArray = PNGEncoder2.encode(resultBitmap.bitmapData);
			var f2 : File = folder.resolvePath(folder.url + ".png");
			
			fs = new FileStream();
			fs.open(f2, FileMode.WRITE);
			fs.writeBytes(ba);
			fs.close();
		}
		
	}

}