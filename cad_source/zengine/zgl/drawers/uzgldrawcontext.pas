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
unit uzgldrawcontext;
{$INCLUDE def.inc}
interface
uses uzepalette,uzbtypesbase,uzbtypes,uzgldrawerabstract,uzeconsts,uzegeometry;
type
TDrawHeplGeometry=procedure  of object;
TDrawingContext=packed record
                   VisibleActualy:TActulity;
                   InfrustumActualy:TActulity;
                   DRAWCOUNT:TActulity;
                   SysLayer:GDBPointer;
                   Zoom:GDBDouble;
                   matrixs:tmatrixs;
                   pcamera:PGDBBaseCamera;
                   GlobalLTScale:GDBDouble;
                   DrawHeplGeometryProc:TDrawHeplGeometry;
                   ForeGroundColorIndex:GDBInteger;
end;
TDrawContext=packed record
                   DrawingContext:TDrawingContext;
                   Subrender:GDBInteger;
                   Selected:GDBBoolean;
                   MaxDetail:GDBBoolean;
                   DrawMode:GDBBoolean;
                   LWDisplayScale:GDBInteger{=2};
                   DefaultLW:GDBInteger{=25};
                   OwnerLineWeight:GDBSmallInt;
                   OwnerColor:GDBInteger;
                   MaxWidth:GDBInteger;
                   ScrollMode:GDBBoolean;
                   drawer:TZGLAbstractDrawer;
                   SystmGeometryDraw:boolean;
                   SystmGeometryColor:TGDBPaletteColor;
             end;
function CreateAbstractRC:TDrawContext;
implementation
function CreateAbstractRC:TDrawContext;
begin
      result.Subrender:=0;
      result.Selected:=false;
      result.DrawingContext.VisibleActualy:=0;
      result.DrawingContext.InfrustumActualy:=0;
      result.DrawingContext.DRAWCOUNT:=0;
      result.DrawingContext.SysLayer:=nil;
      result.MaxDetail:=true;
      result.DrawMode:=true;
      result.LWDisplayScale:=2;
      result.DefaultLW:=25;
      result.OwnerLineWeight:=-3;
      result.OwnerColor:=ClWhite;
      result.MaxWidth:=20;
      result.ScrollMode:=false;
      result.DrawingContext.Zoom:=1;
      result.drawer:=nil;
      result.DrawingContext.matrixs.pmodelMatrix:=@OneMatrix;
      result.DrawingContext.matrixs.pprojMatrix:=@OneMatrix;
      result.DrawingContext.matrixs.pviewport:=@DefaultVP;
      result.DrawingContext.pcamera:=nil;
      result.SystmGeometryDraw:=false;
      result.SystmGeometryColor:=1;
      result.DrawingContext.GlobalLTScale:=1;
      result.DrawingContext.ForeGroundColorIndex:=ClWhite;
end;
begin
end.

