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

unit zedimblocksregister;
{$INCLUDE def.inc}


interface
uses UGDBObjBlockdefArray,zeblockdefsfactory,GDBBlockDef,UGDBDrawingdef,
    memman,zcadsysvars,GDBase,GDBasetypes,GDBGenericSubEntry,gdbEntity;
implementation
uses
    log,GDBManager;
function CreateClosedFilledBlock(dwg:PTDrawingDef;name:GDBString):PGDBObjBlockdef;
var
   BlockDefArray:PGDBObjBlockdefArray;
begin
   BlockDefArray:=dwg^.GetBlockDefArraySimple;
   result:=BlockDefArray.create(name);
   ENTF_CreateLine(result,@result.ObjArray,[0,0,0,1,1,0]);
end;
initialization
  {$IFDEF DEBUGINITSECTION}LogOut('zedimblocksregister.initialization');{$ENDIF}
  RegisterBlockDefCreateFunc('_ClosedFilled',CreateClosedFilledBlock);
finalization
end.