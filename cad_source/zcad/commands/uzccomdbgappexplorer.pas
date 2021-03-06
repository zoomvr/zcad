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

unit uzccomdbgappexplorer;
{$INCLUDE def.inc}

interface
uses
 uzccommandsimpl,uzccommandsabstract,uzbtypes,AppExploreFrm;
implementation
function DbgAppExplorer_com(operands:TCommandOperands):TCommandResult;
begin
  ShowAppExplorer;
  result:=cmd_ok;
end;

begin
CreateCommandFastObjectPlugin(@DbgAppExplorer_com,'DbgAppExplorer',0,0);
end.
