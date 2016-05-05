{
*****************************************************************************
*                                                                           *
*  This file is part of the ZCAD                                            *
*                                                                           *
*  See the file COPYING.modifiedLGPL.txt, included in this distribution,    *
*  for details about the copyright.                                         *
*                                                                           *
*  This program is distributed in the hope that it will be useful,          *
*  but WITHOUT ANY WARRANTY; without even the implied warranty of           *
*  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.                     *
*                                                                           *
*****************************************************************************
}
{
@author(Andrey Zubarev <zamtmn@yandex.ru>)
}
unit uzcftextstyles;
{$INCLUDE def.inc}
{$mode objfpc}{$H+}

interface

uses
  uzcutils,zcchangeundocommand,zcobjectchangeundocommand2,uzcdrawing,LMessages,uzefont,
  uzclog,uzedrawingsimple,uzcsysvars,Classes, SysUtils,
  FileUtil, LResources, Forms, Controls, Graphics, Dialogs,GraphType,
  Buttons, ExtCtrls, StdCtrls, ComCtrls,LCLIntf,lcltype, ActnList,

  uzeconsts,uzestylestexts,uzcdrawings,uzbtypesbase,uzbtypes,varmandef,
  uzcsuptypededitors,

  uzbpaths,uzcinterface, uzcstrconsts, uzcsysinfo,uzbstrproc, uzcshared,UBaseTypeDescriptor,
  uzcimagesmanager, usupportgui, ZListView,uzefontmanager,varman,uzctnrvectorgdbstring,
  uzeentity,uzeenttext;

const
     NameColumn=0;
     FontNameColumn=1;
     FontPathColumn=2;
     HeightColumn=3;
     WidthFactorColumn=4;
     ObliqueColumn=5;

     ColumnCount=5+1;

type
  TFTFilter=(TFTF_All,TFTF_TTF,TFTF_SHX);

  { TTextStylesForm }

  TTextStylesForm = class(TForm)
    DelStyle: TAction;
    MkCurrentStyle: TAction;
    PurgeStyles: TAction;
    RefreshStyles: TAction;
    AddStyle: TAction;
    ActionList1: TActionList;
    FontTypeFilterComboBox: TComboBox;
    Bevel1: TBevel;
    ButtonApplyClose: TBitBtn;
    FontTypeFilterDesc: TLabel;
    DescLabel: TLabel;
    ListView1: TZListView;
    ToolBar1: TToolBar;
    ToolButton_Add: TToolButton;
    ToolButton_Delete: TToolButton;
    ToolButton_MkCurrent: TToolButton;
    Separator1: TToolButton;
    ToolButton_Purge: TToolButton;
    ToolButton_Refresh: TToolButton;
    procedure Aply(Sender: TObject);
    procedure AplyClose(Sender: TObject);
    procedure FontsTypesChange(Sender: TObject);
    procedure PurgeTStyles(Sender: TObject);
    procedure StyleAdd(Sender: TObject);
    procedure DeleteItem(Sender: TObject);
    procedure FormClose(Sender: TObject; var CloseAction: TCloseAction);
    procedure FormCreate(Sender: TObject);
    procedure FormShow(Sender: TObject);
    procedure RefreshListitems(Sender: TObject);
    procedure ListView1SelectItem(Sender: TObject; Item: TListItem;
      Selected: Boolean);
    procedure MkCurrent(Sender: TObject);
    procedure MaceItemCurrent(ListItem:TListItem);
    procedure FillFontsSelector(currentitem:string;currentitempfont:PGDBfont);
    procedure onrsz(Sender: TObject);
    procedure countstyle(ptextstyle:PGDBTextStyle;out e,b,inDimStyles:GDBInteger);
  private
    changedstamp:boolean;
    //EditedItem:TListItem;
    FontsSelector:TEnumData;
    SupportTypedEditors:TSupportTypedEditors;
    FontChange:boolean;
    IsUndoEndMarkerCreated:boolean;
    { private declarations }
    procedure UpdateItem2(Item:TObject);
    procedure CreateUndoStartMarkerNeeded;
    procedure CreateUndoEndMarkerNeeded;
    procedure GetFontsTypesComboValue;
    procedure doTStyleDelete(ProcessedItem:TListItem);

  public
    { public declarations }
    function IsShortcut(var Message: TLMKey): boolean; override;

    {Style name handle procedures}
    function GetStyleName(Item: TListItem):string;
    function CreateNameEditor(Item: TListItem;r: TRect):boolean;
    {Font name handle procedures}
    function GetFontName(Item: TListItem):string;
    function CreateFontNameEditor(Item: TListItem;r: TRect):boolean;
    {Font path handle procedures}
    function GetFontPath(Item: TListItem):string;
    {Height handle procedures}
    function GetHeight(Item: TListItem):string;
    function CreateHeightEditor(Item: TListItem;r: TRect):boolean;
    {Wfactor handle procedures}
    function GetWidthFactor(Item: TListItem):string;
    function CreateWidthFactorEditor(Item: TListItem;r: TRect):boolean;
    {Oblique handle procedures}
    function GetOblique(Item: TListItem):string;
    function CreateObliqueEditor(Item: TListItem;r: TRect):boolean;
  end;

var
  TextStylesForm: TTextStylesForm;
  FontsFilter:TFTFilter;
implementation
{$R *.lfm}
function TTextStylesForm.IsShortcut(var Message: TLMKey): boolean;
var
   OldFunction:TIsShortcutFunc;
begin
   TMethod(OldFunction).code:=@TForm.IsShortcut;
   TMethod(OldFunction).Data:=self;
   result:=IsZShortcut(Message,ActiveControl,nil,OldFunction);
end;

procedure TTextStylesForm.GetFontsTypesComboValue;
begin
     FontTypeFilterComboBox.ItemIndex:=ord(FontsFilter);
end;

procedure TTextStylesForm.CreateUndoStartMarkerNeeded;
begin
  zcPlaceUndoStartMarkerIfNeed(IsUndoEndMarkerCreated,'Change text styles');
end;
procedure TTextStylesForm.CreateUndoEndMarkerNeeded;
begin
  zcPlaceUndoEndMarkerIfNeed(IsUndoEndMarkerCreated);
end;

procedure TTextStylesForm.UpdateItem2(Item:TObject);
var
   newfont:PGDBfont;
begin
     if FontChange then
     begin
          newfont:=FontManager.addFonf(FindInPaths(sysvarPATHFontsPath,pstring(FontsSelector.Enums.getDataMutable(FontsSelector.Selected))^));
          if  newfont<>PGDBTextStyle(TListItem(Item).Data)^.pfont then
          begin
               CreateUndoStartMarkerNeeded;
               with PushCreateTGChangeCommand(PTZCADDrawing(drawings.GetCurrentDWG)^.UndoStack,pointer(PGDBTextStyle(TListItem(Item).Data)^.pfont))^ do
               begin
               PGDBTextStyle(TListItem(Item).Data)^.pfont:=newfont;
               ComitFromObj;
               end;
               with PushCreateTGChangeCommand(PTZCADDrawing(drawings.GetCurrentDWG)^.UndoStack,PGDBTextStyle(TListItem(Item).Data)^.dxfname)^ do
               begin
               PGDBTextStyle(TListItem(Item).Data)^.dxfname:=PGDBTextStyle(TListItem(Item).Data)^.pfont^.Name;
               ComitFromObj;
               end;
          end;
     end;
     ListView1.UpdateItem2(TListItem(Item));
     FontChange:=false;
     FontTypeFilterComboBox.enabled:=true;
end;

{Style name handle procedures}
function TTextStylesForm.GetStyleName(Item: TListItem):string;
begin
  result:=Tria_AnsiToUtf8(PGDBTextStyle(Item.Data)^.Name);
end;
function TTextStylesForm.CreateNameEditor(Item: TListItem;r: TRect):boolean;
begin
  result:=SupportTypedEditors.createeditor(ListView1,Item,r,PGDBTextStyle(Item.Data)^.Name,'GDBAnsiString',@CreateUndoStartMarkerNeeded,r.Bottom-r.Top)
end;
{Font name handle procedures}
function TTextStylesForm.GetFontName(Item: TListItem):string;
begin
  result:=ExtractFileName(PGDBTextStyle(Item.Data)^.pfont^.fontfile);
end;
function TTextStylesForm.CreateFontNameEditor(Item: TListItem;r: TRect):boolean;
begin
  FillFontsSelector(PGDBTextStyle(Item.Data)^.pfont^.fontfile,PGDBTextStyle(Item.Data)^.pfont);
  FontChange:=true;
  FontTypeFilterComboBox.enabled:=false;
  result:=SupportTypedEditors.createeditor(ListView1,Item,r,FontsSelector,'TEnumData',nil,r.Bottom-r.Top,false)
end;
{Font path handle procedures}
function TTextStylesForm.GetFontPath(Item: TListItem):string;
begin
  result:=ExtractFilePath(PGDBTextStyle(Item.Data)^.pfont^.fontfile);
end;
{Height handle procedures}
function TTextStylesForm.GetHeight(Item: TListItem):string;
begin
  result:=floattostr(PGDBTextStyle(Item.Data)^.prop.size);
end;
function TTextStylesForm.CreateHeightEditor(Item: TListItem;r: TRect):boolean;
begin
  result:=SupportTypedEditors.createeditor(ListView1,Item,r,PGDBTextStyle(Item.Data)^.prop.size,'GDBDouble',@CreateUndoStartMarkerNeeded,r.Bottom-r.Top)
end;
{Wfactor handle procedures}
function TTextStylesForm.GetWidthFactor(Item: TListItem):string;
begin
  result:=floattostr(PGDBTextStyle(Item.Data)^.prop.wfactor);
end;
function TTextStylesForm.CreateWidthFactorEditor(Item: TListItem;r: TRect):boolean;
begin
  result:=SupportTypedEditors.createeditor(ListView1,Item,r,PGDBTextStyle(Item.Data)^.prop.wfactor,'GDBDouble',@CreateUndoStartMarkerNeeded,r.Bottom-r.Top)
end;
{Oblique handle procedures}
function TTextStylesForm.GetOblique(Item: TListItem):string;
begin
  result:=floattostr(PGDBTextStyle(Item.Data)^.prop.oblique);
end;
function TTextStylesForm.CreateObliqueEditor(Item: TListItem;r: TRect):boolean;
begin
  result:=SupportTypedEditors.createeditor(ListView1,Item,r,PGDBTextStyle(Item.Data)^.prop.oblique,'GDBDouble',@CreateUndoStartMarkerNeeded,r.Bottom-r.Top)
end;
procedure TTextStylesForm.FillFontsSelector(currentitem:string;currentitempfont:PGDBfont);
var i:integer;
    s:string;
    CurrentFontIndex:integer;
begin
     CurrentFontIndex:=-1;
     FontsSelector.Enums.Free;
     if FontsFilter<>TFTF_SHX then
     for i:=0 to FontManager.ttffontfiles.Count-1 do
     begin
          S:=FontManager.ttffontfiles[i];
          if S=currentitem then
           CurrentFontIndex:=FontsSelector.Enums.Count;
          S:=extractfilename(S);
          FontsSelector.Enums.PushBackData(S);
     end;
     if FontsFilter<>TFTF_TTF then
     for i:=0 to FontManager.shxfontfiles.Count-1 do
     begin
          S:=FontManager.shxfontfiles[i];
          if S=currentitem then
           CurrentFontIndex:=FontsSelector.Enums.Count;
          S:=extractfilename(S);
          FontsSelector.Enums.PushBackData(S);
     end;
     if CurrentFontIndex=-1 then
     begin
          CurrentFontIndex:=FontsSelector.Enums.Count;
          S:=extractfilename(currentitempfont^.fontfile);
          FontsSelector.Enums.PushBackData(S);
     end;
     FontsSelector.Selected:=CurrentFontIndex;
     FontsSelector.Enums.SortAndSaveIndex(FontsSelector.Selected);
end;

procedure TTextStylesForm.onrsz(Sender: TObject);
begin
     Sender:=Sender;
     SupportTypedEditors.freeeditor;
end;

procedure TTextStylesForm.FormCreate(Sender: TObject);
begin
  ActionList1.Images:=IconList;
  ToolBar1.Images:=IconList;
  AddStyle.ImageIndex:=II_Plus;
  DelStyle.ImageIndex:=II_Minus;
  MkCurrentStyle.ImageIndex:=II_Ok;
  PurgeStyles.ImageIndex:=II_Purge;
  RefreshStyles.ImageIndex:=II_Refresh;

  ListView1.SmallImages:=IconList;
  ListView1.DefaultItemIndex:=II_Ok;

  FontsSelector.Enums.init(100);
  SupportTypedEditors:=TSupportTypedEditors.create;
  SupportTypedEditors.OnUpdateEditedControl:=@UpdateItem2;
  FontChange:=false;
  IsUndoEndMarkerCreated:=false;

  setlength(ListView1.SubItems,ColumnCount);

  with ListView1.SubItems[NameColumn] do
  begin
       OnGetName:=@GetStyleName;
       OnClick:=@CreateNameEditor;
  end;
  with ListView1.SubItems[FontNameColumn] do
  begin
       OnGetName:=@GetFontName;
       OnClick:=@CreateFontNameEditor;
  end;
  with ListView1.SubItems[FontPathColumn] do
  begin
       OnGetName:=@GetFontPath;
  end;
  with ListView1.SubItems[HeightColumn] do
  begin
       OnGetName:=@GetHeight;
       OnClick:=@CreateHeightEditor;
  end;
  with ListView1.SubItems[WidthFactorColumn] do
  begin
       OnGetName:=@GetWidthFactor;
       OnClick:=@CreateWidthFactorEditor;
  end;
  with ListView1.SubItems[ObliqueColumn] do
  begin
       OnGetName:=@GetOblique;
       OnClick:=@CreateObliqueEditor;
  end;
end;
procedure TTextStylesForm.MaceItemCurrent(ListItem:TListItem);
begin
     if ListView1.CurrentItem<>ListItem then
     begin
     CreateUndoStartMarkerNeeded;
     with PushCreateTGChangeCommand(PTZCADDrawing(drawings.GetCurrentDWG)^.UndoStack,sysvar.dwg.DWG_CTStyle^)^ do
     begin
          SysVar.dwg.DWG_CTStyle^:=ListItem.Data;
          ComitFromObj;
     end;
     end;
end;
procedure TTextStylesForm.MkCurrent(Sender: TObject);
begin
  if assigned(ListView1.Selected)then
                                     begin
                                     if ListView1.Selected<>ListView1.CurrentItem then
                                       begin
                                         MaceItemCurrent(ListView1.Selected);
                                         ListView1.MakeItemCorrent(ListView1.Selected);
                                         UpdateItem2(ListView1.Selected);
                                       end;
                                     end
                                 else
                                     MessageBox(@rsStyleMustBeSelected[1],@rsWarningCaption[1],MB_OK or MB_ICONWARNING);
end;
procedure TTextStylesForm.FormShow(Sender: TObject);
begin
     GetFontsTypesComboValue;
     RefreshListItems(nil);
end;
procedure TTextStylesForm.RefreshListItems(Sender: TObject);
var
   pdwg:PTSimpleDrawing;
   ir:itrec;
   plp:PGDBTextStyle;
   li:TListItem;
   tscounter:integer;
begin
     ListView1.BeginUpdate;
     ListView1.Clear;
     pdwg:=drawings.GetCurrentDWG;
     tscounter:=0;
     if (pdwg<>nil)and(pdwg<>PTSimpleDrawing(BlockBaseDWG)) then
     begin
       plp:=pdwg^.TextStyleTable.beginiterate(ir);
       if plp<>nil then
       repeat
            li:=ListView1.Items.Add;
            inc(tscounter);
            li.Data:=plp;
            ListView1.UpdateItem(li,drawings.GetCurrentDWG^.GetCurrentTextStyle);
            plp:=pdwg^.TextStyleTable.iterate(ir);
       until plp=nil;
     end;
     ListView1.SortColumn:=1;
     ListView1.SetFocus;
     ListView1.EndUpdate;
     DescLabel.Caption:=Format(rsCountTStylesFound,[tscounter]);
end;

procedure TextStyleCounter(const PInstance,PCounted:GDBPointer;var Counter:GDBInteger);
begin
     if (PGDBObjEntity(PInstance)^.GetObjType=GDBMTextID)or(PGDBObjEntity(PInstance)^.GetObjType=GDBTextID) then
     if PCounted=PGDBObjText(PInstance)^.TXTStyleIndex then
                                                           inc(Counter);
end;
procedure TextStyleCounterInDimStyles(const PInstance,PCounted:GDBPointer;var Counter:GDBInteger);
begin
     //if PCounted=PGDBDimStyle(PInstance)^.Text.DIMTXSTY then
     //                                                      inc(Counter);
end;
procedure TTextStylesForm.countstyle(ptextstyle:PGDBTextStyle;out e,b,inDimStyles:GDBInteger);
var
   pdwg:PTSimpleDrawing;
begin
  pdwg:=drawings.GetCurrentDWG;
  e:=0;
  pdwg^.mainObjRoot.IterateCounter(ptextstyle,e,@TextStyleCounter);
  b:=0;
  pdwg^.BlockDefArray.IterateCounter(ptextstyle,b,@TextStyleCounter);
  inDimStyles:=0;
  pdwg^.DimStyleTable.IterateCounter(ptextstyle,inDimStyles,@TextStyleCounterInDimStyles);
end;
procedure TTextStylesForm.ListView1SelectItem(Sender: TObject; Item: TListItem;Selected: Boolean);
var
   pstyle:PGDBTextStyle;
   //pdwg:PTSimpleDrawing;
   inent,inblock,indimstyles:integer;
begin
     if selected then
     begin
          //pdwg:=drawings.GetCurrentDWG;
          pstyle:=(Item.Data);
          countstyle(pstyle,inent,inblock,indimstyles);
          DescLabel.Caption:=Format(rsTextStyleUsedIn,[pstyle^.Name,inent,inblock,indimstyles]);
     end;
end;

procedure TTextStylesForm.StyleAdd(Sender: TObject);
var
   pstyle,pcreatedstyle:PGDBTextStyle;
   pdwg:PTSimpleDrawing;
   stylename:string;
   //counter:integer;
   //li:TListItem;
   domethod,undomethod:tmethod;
begin
  pdwg:=drawings.GetCurrentDWG;
  if assigned(ListView1.Selected)then
                                     pstyle:=(ListView1.Selected.Data)
                                 else
                                     pstyle:=pdwg^.GetCurrentTextStyle;

  stylename:=pdwg^.TextStyleTable.GetFreeName(Tria_Utf8ToAnsi(rsNewTextStyleNameFormat),1);
  if stylename='' then
  begin
    uzcshared.ShowError(rsUnableSelectFreeTextStylerName);
    exit;
  end;

  pdwg^.TextStyleTable.AddItem(stylename,pcreatedstyle);
  pcreatedstyle^:=pstyle^;
  pcreatedstyle^.Name:=stylename;

  domethod:=tmethod(@pdwg^.TextStyleTable.PushBackData);
  undomethod:=tmethod(@pdwg^.TextStyleTable.RemoveData);
  CreateUndoStartMarkerNeeded;
  with PushCreateTGObjectChangeCommand2(PTZCADDrawing(drawings.GetCurrentDWG)^.UndoStack,pcreatedstyle,tmethod(domethod),tmethod(undomethod))^ do
  begin
       AfterAction:=false;
       //comit;
  end;

  ListView1.AddCreatedItem(pcreatedstyle,drawings.GetCurrentDWG^.GetCurrentTextStyle);
end;
procedure TTextStylesForm.doTStyleDelete(ProcessedItem:TListItem);
var
   domethod,undomethod:tmethod;
   pstyle:PGDBTextStyle;
   pdwg:PTSimpleDrawing;
begin
  pdwg:=drawings.GetCurrentDWG;
  pstyle:=(ProcessedItem.Data);
  domethod:=tmethod(@pdwg^.TextStyleTable.RemoveData);
  undomethod:=tmethod(@pdwg^.TextStyleTable.PushBackData);
  CreateUndoStartMarkerNeeded;
  with PushCreateTGObjectChangeCommand2(PTZCADDrawing(pdwg)^.UndoStack,pstyle,tmethod(domethod),tmethod(undomethod))^ do
  begin
       AfterAction:=false;
       comit;
  end;
  ListView1.Items.Delete(ListView1.Items.IndexOf(ProcessedItem));
end;

procedure TTextStylesForm.DeleteItem(Sender: TObject);
var
   pstyle:PGDBTextStyle;
   pdwg:PTSimpleDrawing;
   inEntities,inBlockTable,indimstyles:GDBInteger;
   //domethod,undomethod:tmethod;
begin
  pdwg:=drawings.GetCurrentDWG;
  if assigned(ListView1.Selected)then
                                     begin
                                     pstyle:=(ListView1.Selected.Data);
                                     countstyle(pstyle,inEntities,inBlockTable,indimstyles);
                                     if ListView1.Selected.Data=pdwg^.GetCurrentTextStyle then
                                     begin
                                       ShowError(rsCurrentStyleCannotBeDeleted);
                                       exit;
                                     end;
                                     if (inEntities+inBlockTable+indimstyles)>0 then
                                                  begin
                                                       ShowError(rsUnableDelUsedStyle);
                                                       exit;
                                                  end;

                                     doTStyleDelete(ListView1.Selected);

                                     DescLabel.Caption:='';
                                     end
                                 else
                                     ShowError(rsStyleMustBeSelected);
end;

procedure TTextStylesForm.AplyClose(Sender: TObject);
begin
     close;
end;

procedure TTextStylesForm.FontsTypesChange(Sender: TObject);
begin
  FontsFilter:=TFTFilter(FontTypeFilterComboBox.ItemIndex);
end;

procedure TTextStylesForm.PurgeTStyles(Sender: TObject);
var
   i,purgedcounter:integer;
   ProcessedItem:TListItem;
   inEntities,inBlockTable,indimstyles:GDBInteger;
   PCurrentStyle:PGDBTextStyle;
begin
     i:=0;
     purgedcounter:=0;
     PCurrentStyle:=drawings.GetCurrentDWG^.GetCurrentTextStyle;
     if ListView1.Items.Count>0 then
     begin
       repeat
          ProcessedItem:=ListView1.Items[i];
          countstyle(ProcessedItem.Data,inEntities,inBlockTable,indimstyles);
          if (ProcessedItem.Data<>PCurrentStyle)and((inEntities+inBlockTable+indimstyles)=0) then
          begin
           doTStyleDelete(ProcessedItem);
           inc(purgedcounter);
          end
          else
           inc(i);
       until i>=ListView1.Items.Count;
     end;
     DescLabel.Caption:=Format(rsCountTStylesPurged,[purgedcounter]);
end;
procedure TTextStylesForm.Aply(Sender: TObject);
begin
     if changedstamp then
     begin
           if assigned(UpdateVisibleProc) then UpdateVisibleProc;
           zcRedrawCurrentDrawing;
     end;
end;

procedure TTextStylesForm.FormClose(Sender: TObject; var CloseAction: TCloseAction
  );
begin
     Aply(nil);
     CreateUndoEndMarkerNeeded;
     FontsSelector.Enums.done;
     SupportTypedEditors.Free;
end;
initialization
  FontsFilter:=TFTF_SHX;
end.

