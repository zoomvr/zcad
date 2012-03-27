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

unit GDBPlain;
{$INCLUDE def.inc}

interface
uses
gl,
 {GDBEntity,}geometry,GDBWithLocalCS,gdbase,gdbasetypes,varmandef,OGLSpecFunc{,GDBEntity};
type
{EXPORT+}
GDBObjPlain=object(GDBObjWithLocalCS)
                  Outbound:OutBound4V;

                  procedure DrawGeometry(lw:GDBInteger;var DC:TDrawContext{infrustumactualy:TActulity;subrender:GDBInteger});virtual;
            end;
{EXPORT-}
implementation
uses
    log;
//uses UGDBDescriptor;
procedure GDBObjPlain.DrawGeometry;
var
  p: GDBVertex;
begin
  if (sysvar.DWG.DWG_SystmGeometryDraw^){and(POGLWnd.subrender=0)} then
  begin
       {oglsm.myglbegin(GL_LINES);
       oglsm.myglvertex3dv(@outbound[0]);
       oglsm.myglvertex3dv(@outbound[1]);
       oglsm.myglvertex3dv(@outbound[1]);
       oglsm.myglvertex3dv(@outbound[2]);
       oglsm.myglvertex3dv(@outbound[2]);
       oglsm.myglvertex3dv(@outbound[3]);
       oglsm.myglvertex3dv(@outbound[3]);
       oglsm.myglvertex3dv(@outbound[0]);
       oglsm.myglend;}

       oglsm.myglbegin(GL_LINES);
       oglsm.glcolor3ub(255,0,0);
       p:=geometry.VertexAdd(Local.P_insert,Local.Basis.ox);
       oglsm.myglvertex3dv(@Local.P_insert);
       oglsm.myglvertex3dv(@p);

       oglsm.glcolor3ub(0,255,0);
       p:=geometry.VertexAdd(Local.P_insert,Local.Basis.oy);
       oglsm.myglvertex3dv(@Local.P_insert);
       oglsm.myglvertex3dv(@p);

       oglsm.glcolor3ub(0,0,255);
       p:=geometry.VertexAdd(Local.P_insert,Local.Basis.oz);
       oglsm.myglvertex3dv(@Local.P_insert);
       oglsm.myglvertex3dv(@p);

       oglsm.myglend;
  end;
  inherited;

end;
begin
  {$IFDEF DEBUGINITSECTION}LogOut('GDBPlain.initialization');{$ENDIF}
end.
