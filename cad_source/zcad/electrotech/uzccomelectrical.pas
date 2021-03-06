(*----------------------------------------------------------------------------*)
(*                  Copyright (c) 2004-2010 Antrey Zubarev                    *)
(*----------------------------------------------------------------------------*)
{
@author(Andrey Zubarev <zamtmn@yandex.ru>) 
}

unit uzccomelectrical;
{$INCLUDE def.inc}

interface
uses
  gzctnrvectortypes,uzglviewareageneral,uzctranslations,zcobjectchangeundocommand2,
  zcmultiobjectcreateundocommand,uzeentitiesmanager,uzedrawingdef,
  uzcenitiesvariablesextender,uzgldrawcontext,uzcdrawing,uzcvariablesutils,
  uzcstrconsts,UGDBSelectedObjArray,uzeentityfactory,uzcsysvars,
  csvdocument,
  UGDBOpenArrayOfPV,uzeentblockinsert,devices,UGDBTree,uzcdrawings,uzbtypesbase,
  uzccommandsmanager,uzccomdraw,uzcentelleader,
  uzccommandsabstract,
  uzccommandsimpl,
  uzbgeomtypes,uzbtypes,
  uzcutils,
  sysutils,
  {fileutil}LazUTF8,
  varmandef,
  uzglviewareadata,
  uzcinterface,
  uzegeometry,
  uzbmemman,
  uzeconsts,
  uzeentity,uzeentline,
  uzcentnet,
  uzcshared,uzeentsubordinated,uzcentcable,varman,uzcdialogsfiles,uunitmanager,
  gzctnrvectorpobjects,uzcbillofmaterial,uzccablemanager,uzeentdevice,uzeenttable,
  uzbpaths,uzctnrvectorgdbstring,math,Masks,uzclog,uzccombase,uzbstrproc,
  uzeentmtext,uzeblockdef,UGDBPoint3DArray,uzcdevicebaseabstract,uzelongprocesssupport,LazLogger,
  generics.Collections;
type
{Export+}
  TFindType=(
               TFT_Obozn(*'**обозначении'*),
               TFT_DBLink(*'**материале'*),
               TFT_DESC_MountingDrawing(*'**сокращенноммонтажномчертеже'*),
               TFT_variable(*'??указанной переменной'*)
             );
PTBasicFinter=^TBasicFinter;
TBasicFinter=packed record
                   IncludeCable:GDBBoolean;(*'Include filter'*)
                   IncludeCableMask:GDBString;(*'Include mask'*)
                   ExcludeCable:GDBBoolean;(*'Exclude filter'*)
                   ExcludeCableMask:GDBString;(*'Exclude mask'*)
             end;
  PTFindDeviceParam=^TFindDeviceParam;
  TFindDeviceParam=packed record
                        FindType:TFindType;(*'Find in'*)
                        FindMethod:GDBBoolean;(*'Use symbols *, ?'*)
                        FindString:GDBString;(*'Text'*)
                    end;
     GDBLine=packed record
                  lBegin,lEnd:GDBvertex;
              end;
  PTELCableComParam=^TELCableComParam;
  TELCableComParam=packed record
                        Traces:TEnumData;(*'Trace'*)
                        PCable:{PGDBObjCable}GDBPointer;(*'Cabel'*)
                        PTrace:{PGDBObjNet}GDBPointer;(*'Trace (pointer)'*)
                   end;
  TELLeaderComParam=packed record
                        Scale:GDBDouble;(*'Scale'*)
                        Size:GDBInteger;(*'Size'*)
                        twidth:GDBDouble;(*'Width'*)
                   end;
{Export-}
  El_Wire_com = object(CommandRTEdObject)
    New_line: PGDBObjLine;
    FirstOwner,SecondOwner,OldFirstOwner:PGDBObjNet;
    constructor init(cn:GDBString;SA,DA:TCStartAttr);
    procedure CommandStart(Operands:TCommandOperands); virtual;
    procedure CommandCancel; virtual;
    function BeforeClick(wc: GDBvertex; mc: GDBvertex2DI; var button: GDBByte;osp:pos_record): GDBInteger; virtual;
    function AfterClick(wc: GDBvertex; mc: GDBvertex2DI; var button: GDBByte;osp:pos_record): GDBInteger; virtual;
  end;

  EM_SRBUILD_com = object(FloatInsert_com)
    procedure Command(Operands:TCommandOperands); virtual;
  end;
  EM_SEPBUILD_com = object(FloatInsertWithParams_com)
    procedure Command(Operands:TCommandOperands); virtual;
    procedure BuildDM(Operands:TCommandOperands); virtual;
  end;
  KIP_CDBuild_com=object(FloatInsert_com)
    procedure Command(Operands:TCommandOperands); virtual;
  end;

  KIP_LugTableBuild_com=object(FloatInsert_com)
    procedure Command(Operands:TCommandOperands); virtual;
  end;


    (*PGDBEmSEPDeviceNode=^GDBEmSEPDeviceNode;
    GDBEmSEPDeviceNode=object(GDBVisNode)
                              NodeName:GDBString;
                              upcable:PTCableDesctiptor;
                              dev,shell:PGDBObjDevice;
                              function GetNodeName:GDBString;virtual;
                       end;*)
   TBGMode=(BGAvtomat,DG1J,BGComm,DG2J,BGNagr);
var
   Wire:El_Wire_com;
   p3dpl:PGDBObjCable;

   //pco:pCommandRTEdObjectPlugin;
   FindDeviceParam:TFindDeviceParam;

   CableManager:TCableManager;

   pcabcom,pfindcom:pCommandRTEdObjectPlugin;
   cabcomparam:TELCableComParam;
   csel:pCommandFastObjectPlugin;
   MainSpecContentFormat:TZctnrVectorGDBString;

   EM_SRBUILD:EM_SRBUILD_com;
   EM_SEPBUILD:EM_SEPBUILD_com;
   em_sepbuild_params:TBasicFinter;
   KIP_CDBuild:KIP_CDBuild_com;
   KIP_LugTableBuild:KIP_LugTableBuild_com;

   //treecontrol:ZTreeViewGeneric;
   //zf:zform;
   ELLeaderComParam:TELLeaderComParam;

{procedure startup;
procedure finalize;}
procedure Cable2CableMark(pcd:PTCableDesctiptor;pv:pGDBObjDevice);
implementation
function GetCableMaterial(pcd:PTCableDesctiptor):GDBString;
var
   {pvn,}{pvm,}pvmc{,pvl}:pvardesk;
   line:gdbstring;
   eq:pvardesk;
begin
                                        pvmc:=FindVariableInEnt(pcd^.StartSegment,'DB_link');
                                        if pvmc<>nil then
                                        begin
                                        line:=pstring(pvmc^.data.Instance)^;
                                        eq:=DWGDBUnit.FindVariable(line);
                                        if eq=nil then
                                                      result:='(!)'+line
                                                  else
                                                      begin
                                                           result:=PDbBaseObject(eq^.data.Instance)^.NameShort;
                                                      end;
                                        end
                                        else
                                            result:=rsNotSpecified;
end;
procedure Cable2CableMark(pcd:PTCableDesctiptor;pv:pGDBObjDevice);
var
   {pvn,}pvm,{pvmc,}pvl:pvardesk;
   //line:gdbstring;
   //eq:pvardesk;
   pentvarext:PTVariablesExtender;
begin
     pentvarext:=pv^.GetExtension(typeof(TVariablesExtender));
     pvm:=pentvarext^.entityunit.FindVariable('CableMaterial');
                        if pvm<>nil then
                                    begin
                                         pstring(pvm^.data.Instance)^:={Tria_Utf8ToAnsi}( GetCableMaterial(pcd));
                                        {pvmc:=pcd^.StartSegment^.FindVariable('DB_link');
                                        if pvmc<>nil then
                                        begin
                                        line:=pstring(pvmc^.data.Instance)^;
                                        eq:=DWGDBUnit.FindVariable(line);
                                        if eq=nil then
                                                      pstring(pvm^.data.Instance)^:='(!)'+line
                                                  else
                                                      begin
                                                           pstring(pvm^.data.Instance)^:=PDbBaseObject(eq^.data.Instance)^.NameShort;
                                                      end;
                                        end
                                        else
                                            pgdbstring(pvm^.data.Instance)^:='Не определен';}
                                    end;
                       pvl:=pentvarext^.entityunit.FindVariable('CableLength');
                       if pvl<>nil then
                                       pgdbdouble(pvl^.data.Instance)^:=pcd^.length;
end;
{function GDBEmSEPDeviceNode.GetNodeName:GDBString;
begin
     result:=nodename;
end;}
procedure IP(pnode:PGDBBaseNode;PProcData:Pointer);
//var
//   pvd:pvardesk;
begin
(*     if PGDBEmSEPDeviceNode(pnode)^.upcable<>nil then
     begin
          pvd:=PGDBEmSEPDeviceNode(pnode)^.upcable^.StartSegment.OU.FindVariable('GC_HDGroup');
          if pvd<>nil then
          if PGDBInteger(pvd^.data.Instance)^>PGDBInteger(Pprocdata)^ then
             PGDBInteger(Pprocdata)^:=PGDBInteger(pvd^.data.Instance)^;
     end; *)
end;
(*function icf (pnode:PGDBBaseNode;PExpr:GDBPointer):GDBBoolean;
//var
//   pvd:pvardesk;
begin
     result:=false;
     if PGDBEmSEPDeviceNode(pnode)^.upcable<>nil then
     begin
          pvd:=PGDBEmSEPDeviceNode(pnode)^.upcable^.StartSegment.OU.FindVariable('GC_HDGroup');
          if pvd<>nil then
          if PGDBInteger(pvd^.data.Instance)^=PGDBInteger(PExpr)^ then
             result:=true;
     end;
end;*)
function g2x(g:gdbinteger):GDBInteger;
begin
     result:=30*g;
end;
function TBGMode2y(bgm:TBGMode):GDBDouble;
begin
     case bgm of
       BGAvtomat:
                 result:=0;
       DG1J:
            result:=-40;
       BGComm:
              result:=-57.5;
       DG2J:
            result:=-75;
       BGNagr:
              result:=-121.5;
     end;
end;
function insertblock(bname,obozn:GDBString;p:gdbVertex):TBoundingBox;
var
   pgdbins:pgdbobjblockinsert;
   pbdef:PGDBObjBlockdef;
   ptext:PGDBObjMText;
   DC:TDrawContext;
begin
          pbdef:=drawings.CurrentDWG^.BlockDefArray.getblockdef(bname);
          dc:=drawings.GetCurrentDWG^.CreateDrawingRC;

          pbdef^.getonlyoutbound(dc);
          //pbdef^.calcbb;
          result:=pbdef.vp.BoundingBox;

          pointer(pgdbins):=drawings.CurrentDWG.ConstructObjRoot.ObjArray.CreateInitObj(GDBBlockInsertID,@drawings.CurrentDWG.ConstructObjRoot);
          pgdbins^.name:=bname;
          pgdbins^.Local.P_insert:=p;
          pgdbins^.BuildGeometry(drawings.GetCurrentDWG^);
          pgdbins^.FormatEntity(drawings.GetCurrentDWG^,dc);

          //pointer(ptext):=drawings.CurrentDWG.ConstructObjRoot.ObjArray.CreateInitObj(GDBMtextID,@drawings.CurrentDWG.ConstructObjRoot);

          if obozn<>'' then
          begin
          ptext:=pointer(AllocEnt(GDBMtextID));
          ptext^.init(@drawings.CurrentDWG.ConstructObjRoot,drawings.GetCurrentDWG.LayerTable.getAddres('TEXT'),sysvar.dwg.DWG_CLinew^,obozn,CreateVertex(p.x+pbdef.vp.BoundingBox.LBN.x-1,p.y,p.z),2.5,0,0.65,RightAngle,jsbc,1,1);
          drawings.CurrentDWG.ConstructObjRoot.ObjArray.AddPEntity(ptext^);
          ptext^.FormatEntity(drawings.GetCurrentDWG^,dc);
          end;

end;
procedure drawlineandtext(pcabledesk:PTCableDesctiptor;p1,p2:GDBVertex);
var
   pl:pgdbobjline;
   a:gdbdouble;
   ptext:PGDBObjMText;
   v:gdbvertex;
   DC:TDrawContext;
begin
     pl:=pointer(AllocEnt(GDBLineID));
     pl^.init(@drawings.CurrentDWG.ConstructObjRoot,drawings.GetCurrentDWG.GetCurrentLayer,sysvar.dwg.DWG_CLinew^,p1,p2);
     drawings.CurrentDWG.ConstructObjRoot.ObjArray.AddPEntity(pl^);
     dc:=drawings.GetCurrentDWG^.CreateDrawingRC;
     pl^.Formatentity(drawings.GetCurrentDWG^,dc);
     if pcabledesk<>nil then
     begin
          v:=vertexsub(p1,p2);
          v:=normalizevertex(v);
          if (abs (v.x) < 1/64) and (abs (v.y) < 1/64) then
                                                                    v:=CrossVertex(YWCS,v)
                                                                else
                                                                    v:=CrossVertex(ZWCS,v);
          if {v.x*}v.y<0 then
                          begin
                               {a:=v.x;
                               v.x:=v.y;
                               v.y:=a;}
                               v:=uzegeometry.VertexMulOnSc(v,-1);
                               a:=vertexangle(PGDBVertex2d(@p1)^,PGDBVertex2d(@p2)^)*180/pi;
                          end
                          else
                              a:=180+vertexangle(PGDBVertex2d(@p1)^,PGDBVertex2d(@p2)^)*180/pi;

          ptext:=pointer(AllocEnt(GDBMtextID));
          ptext^.init(@drawings.CurrentDWG.ConstructObjRoot,drawings.GetCurrentDWG.LayerTable.getAddres('TEXT'),sysvar.dwg.DWG_CLinew^,GetCableMaterial(pcabledesk)+' L='+floattostr(pcabledesk^.length)+'м',vertexadd(Vertexmorph(p1,p2,0.5),v),2.5,0,0.65,a,jsbc,vertexlength(p1,p2),1);
          drawings.CurrentDWG.ConstructObjRoot.ObjArray.AddPEntity(ptext^);
          ptext^.Formatentity(drawings.GetCurrentDWG^,dc);

          ptext:=pointer(AllocEnt(GDBMtextID));
          ptext^.init(@drawings.CurrentDWG.ConstructObjRoot,drawings.GetCurrentDWG.LayerTable.getAddres('TEXT'),sysvar.dwg.DWG_CLinew^,pcabledesk^.Name,vertexsub(Vertexmorph(p1,p2,0.5),v),2.5,0,0.65,a,jstc,vertexlength(p1,p2),1);
          drawings.CurrentDWG.ConstructObjRoot.ObjArray.AddPEntity(ptext^);
          ptext^.Formatentity(drawings.GetCurrentDWG^,dc);

     end;
     
end;
procedure drawcable(pcabledesk:PTCableDesctiptor;p1,p2:GDBVertex;g1,g2:TBoundingBox;bgm1,bgm2:TBGMode);
//var
//   pl:pgdbobjline;
begin
     if abs(p1.x-p2.x)<eps then
                               drawlineandtext(pcabledesk,createvertex(p1.x,p1.y+g1.LBN.y,p1.z),createvertex(p2.x,p2.y+g2.RTF.y,p2.z))
else if ({bgm1=bgm2}abs(p1.y-p2.y)<eps)and(bgm1=BGNagr) then
                           begin
                                drawlineandtext(nil,createvertex(p1.x,p1.y+g1.RTF.y,p1.z),createvertex(p1.x+2,p1.y+g1.RTF.y+10,p1.z));
                                drawlineandtext(pcabledesk,createvertex(p1.x+2,p1.y+g1.RTF.y+10,p1.z),createvertex(p2.x-2,p1.y+g1.RTF.y+10,p2.z));
                                drawlineandtext(nil,createvertex(p2.x,p2.y+g2.RTF.y,p2.z),createvertex(p2.x-2,p1.y+g1.RTF.y+10,p2.z));
                           end
else if bgm1=bgm2 then
                           begin
                                if abs(p1.y-p2.y)<eps then
                                                          drawlineandtext(pcabledesk,createvertex(p1.x+g1.RTF.x,p1.y,p1.z),createvertex(p2.x+g2.LBN.x,p2.y,p2.z))
                                                      else
                                begin
                                     drawlineandtext(pcabledesk,createvertex(p1.x+g1.rtf.x,p1.y,p1.z),createvertex(p2.x,p1.y,p1.z));
                                     drawlineandtext(nil,createvertex(p2.x,p1.y,p1.z),createvertex(p2.x,p2.y+g2.RTF.y,p2.z));
                                end;
                           end

else if bgm1<bgm2 then
                           begin
                                drawlineandtext(nil,createvertex(p1.x,p1.y+g1.LBN.y,p1.z),createvertex(p1.x+1,p1.y+g1.LBN.y-1,p1.z));
                                drawlineandtext(pcabledesk,createvertex(p1.x+1,p1.y+g1.LBN.y-1,p1.z),createvertex(p2.x,p1.y+g1.LBN.y-1,p1.z));
                                drawlineandtext(nil,createvertex(p2.x,p1.y+g1.LBN.y-1,p1.z),createvertex(p2.x,p2.y+g2.RTF.y,p2.z));
                           end;

end;
//TBGMode=(BGAvtomat,DG1J,BGComm,DG2J,BGNagr);
(*procedure EM_SEP_build_group(const cman:TCableManager;const node:PGDBEmSEPDeviceNode;var group:GDBInteger;P1:GDBVertex;var BGM:TBGMode;oldgabarit:GDBBoundingBbox);
var
   pvd:pvardesk;
   tempbgm,newBGM,nextBGM,TnextBGM:TBGMode;
   ir:itrec;
   subnode:PGDBEmSEPDeviceNode;
   tempgroup,maxgroup:gdbinteger;
   pgdbins:pgdbobjblockinsert;
   name:GDBString;
   gabarit:GDBBoundingBbox;
   y:GDBDouble;
   p:gdbvertex;
begin
          drawings.AddBlockFromDBIfNeed(drawings.GetCurrentDWG,'EM_PSRS_HEAD');
          drawings.AddBlockFromDBIfNeed(drawings.GetCurrentDWG,'DEVICE_EM_PSRS_EL');
          pointer(pgdbins):=drawings.CurrentDWG.ConstructObjRoot.ObjArray.CreateInitObj(GDBBlockInsertID,@drawings.CurrentDWG.ConstructObjRoot);
          pgdbins^.name:='EM_PSRS_HEAD';
          pgdbins^.Local.P_insert:=createvertex(-15,0,0);
          pgdbins^.BuildGeometry;
          pgdbins^.Format;

     pvd:=node.shell.OU.FindVariable('Device_Type');
     if pvd<>nil then
     case
         PTDeviceType(pvd^.data.Instance)^ of
         TDT_SilaPotr,TDT_SilaIst:begin
                                       nextBGM:=BGNagr;
                                  end;
         TDT_Junction:begin
                             if bgm=BGAvtomat then
                                                  nextBGM:=DG1J
                                              else
                                                  nextBGM:=DG2J;
                      end;
         TDT_SilaComm:begin
                           nextBGM:=BGComm;
                      end;
     end;
     tnextBGM:=nextBGM;
     if node.SubNode=nil then
                             nextBGM:=BGNagr;

     newBGM:=NextBGM;
     tempgroup:=group;

          if node.shell<>nil then
          begin
          name:='';
          pvd:=node.shell.ou.FindVariable('NMO_Name');
                         if pvd<>nil then
                                         name:=pgdbstring(pvd.data.Instance)^;
          //y:=TBGMode2y(nextBGM);
          p:=createvertex(g2x(group),TBGMode2y(nextBGM),0);
          gabarit:=insertblock(node.shell.Name,name,p);
          drawcable(node.upcable,p1,p,oldgabarit,gabarit,bgm,tnextbgm);
          y:=y+gabarit.lbn.y;

          if nextBGM=BGNagr then
          begin
          pgdbins:=addblockinsert(@drawings.CurrentDWG.ConstructObjRoot,@drawings.CurrentDWG.ConstructObjRoot.ObjArray,createvertex(g2x(group),-128,0),1,0,'DEVICE_EM_PSRS_EL');
          node.shell.Format;
          node.shell.OU.CopyTo(@pgdbins.OU);
          // pointer(pgdbins):=drawings.CurrentDWG.ConstructObjRoot.ObjArray.CreateInitObj(GDBBlockInsertID,@drawings.CurrentDWG.ConstructObjRoot);
          // pgdbins^.name:='DEVICE_EM_PSRS_EL';
          // pgdbins^.Local.P_insert:=createvertex(g2x(group),-128,0);
          pgdbins^.BuildGeometry;
          pgdbins^.Format;
          end;

          if (NextBGM=BGNagr){or(NextBGM<=BGM)} then
                                  inc(tempgroup);
          end;

     if node.SubNode<>nil then
     begin
          node.SubNode.Invert;
          subnode:=node.SubNode^.beginiterate(ir);
          if subnode<>nil then
          repeat
                tempbgm:=nextbgm;

               //                 if {(nextBGM=BGNagr)and}(tempBGM=BGNagr) then
               //                                          inc(tempgroup);

                EM_SEP_build_group(cman,subnode,tempgroup,p,tempbgm,gabarit);

                subnode:=node.SubNode^.iterate(ir);
          until subnode=nil;
          node.SubNode.Invert;
     end;
     group:=tempgroup;
     bgm:=NextBGM;
          end;

procedure EM_SEP_build_graphix(const cman:TCableManager;const tree:PTGDBTree);
var
   group,groupmax,dg:GDBInteger;
   pgroupnode:PGDBEmSEPDeviceNode;
   BGM:TBGMode;
   gabarit:GDBBoundingBbox;
begin
     groupmax:=0;
     dg:=0;
     tree^.IterateProc(@ip,false,@groupmax);
     for group := 1 to groupmax do
       begin
            gabarit.LBN:=nulvertex;
            gabarit.RTF:=nulvertex;
            pointer(pgroupnode):=tree^.IterateFind(@icf,@group,false);
            if pgroupnode<>nil then
                                   begin
                                        BGM:=BGAvtomat;
                                        EM_SEP_build_group(cman,pgroupnode,dg,createvertex(g2x(dg),0,0),BGM,gabarit);
                                   end;
       end;
end;
procedure EM_SEP_build_tree(const cman:TCableManager;var tree:PTGDBTree;pobj: pGDBObjEntity);
var
   ir2,ir3:itrec;
   pcabledesk:PTCableDesctiptor;
   root2:PGDBEmSEPDeviceNode;
   sd:PGDBObjDevice;
   pvd:pvardesk;
   name:GDBString;
   pendobj: pGDBObjEntity;
   dev,shell:PGDBObjDevice;
   oldtree:PTGDBTree;
   ptree:^PTGDBTree;
   firstseg:boolean;
begin
              oldtree:=nil;
              ptree:=@tree;
              pcabledesk:=cman.beginiterate(ir2);
              if pcabledesk<>nil then
              repeat
                    sd:=pointer(pcabledesk^.StartDevice^.FindShellByClass(TDC_Shell));
                    if sd<>nil then
                    if sd=pointer(pobj) then
                    begin
                         if tree=nil then
                         begin
                              gdbgetmem({$IFDEF DEBUGBUILD}'{E1158636-E1BD-49B8-BFB2-25723FC26625}',{$ENDIF}pointer(tree),sizeof(TGDBTree));
                              tree.init(10);
                              ptree:=@tree;
                              if oldtree=nil then
                              begin
                              oldtree:=tree;
                              end;
                         end;
                         firstseg:=true;
                         dev:=pcabledesk^.Devices.beginiterate(ir3);
                         dev:=pcabledesk^.Devices.iterate(ir3);
                         if dev<>nil then
                         repeat
                               shell:=pointer(dev^.FindShellByClass(TDC_Shell));


                         gdbgetmem({$IFDEF DEBUGBUILD}'{E1158636-E1BD-49B8-BFB2-25723FC26625}',{$ENDIF}pointer(root2),sizeof(GDBEmSEPDeviceNode));
                         root2^.initnul;
                         pvd:=shell.ou.FindVariable('NMO_Name');
                         if pvd<>nil then
                                         name:=pgdbstring(pvd.data.Instance)^;
                         //if name= then
                         

                         root2^.NodeName:=name;
                         root2^.upcable:=nil;
                         root2^.shell:=shell;
                         if firstseg then
                         begin
                         root2^.NodeName:=root2^.NodeName+'-('+pcabledesk^.Name+')';
                         root2^.upcable:=pcabledesk;
                         firstseg:=false;
                         end;

                         if ptree^=nil then
                         begin
                              gdbgetmem({$IFDEF DEBUGBUILD}'{E1158636-E1BD-49B8-BFB2-25723FC26625}',{$ENDIF}pointer(ptree^),sizeof(TGDBTree));
                              ptree^.init(10);
                         end;

                         ptree^^.AddNode(root2);

                         tree:=root2.SubNode;
                         ptree:=@root2.SubNode;

                         if shell<>nil then
                                           EM_SEP_build_tree(cman,root2.SubNode,shell);


                               dev:=pcabledesk^.Devices.iterate(ir3);
                         until dev=nil;

                         tree:=oldtree;
                         ptree:=@tree;
                    end;


                    pcabledesk:=cman.iterate(ir2);
              until pcabledesk=nil;
end;
*)
procedure EM_SEPBUILD_com.BuildDM(Operands:TCommandOperands);
begin
    //commandmanager.DMAddProcedure('test1','подсказка1',nil);
    commandmanager.DMAddMethod('Разместить','подсказка3',run);
    commandmanager.DMAddMethod('Разместить','подсказка3',run);
    commandmanager.DMAddMethod('Разместить','подсказка3',run);
    commandmanager.DMShow;
end;
procedure EM_SEPBUILD_com.Command(Operands:TCommandOperands);
begin

end;

(*procedure EM_SEPBUILD_com.Command(Operands:pansichar);
var
      pobj: pGDBObjEntity;
      ir:itrec;
      counter:integer;
      //tcd:TCopyObjectDesc;
      pvd:pvardesk;
      name:GDBString;
      cman:TCableManager;

      root:PGDBEmSEPDeviceNode;
begin

commandmanager.DMShow;

  cman.init;
  cman.build;
  drawings.GetCurrentDWG.OGLwindow1.SetMouseMode((MGet3DPoint) or (MMoveCamera) or (MRotateCamera));



  counter:=0;
  cman.init;
  cman.build;
             drawings.GetCurrentDWG.OGLwindow1.SetMouseMode((MGet3DPoint) or (MMoveCamera) or (MRotateCamera));

  pobj:=drawings.GetCurrentROOT.ObjArray.beginiterate(ir);
  if pobj<>nil then
  begin
  repeat
    if pobj.selected then
    if pobj.GetObjType=GDBDeviceID then
    begin
         pvd:=pobj^.ou.FindVariable('Device_Type');
         if pvd<>nil then
         if PTDeviceType(pvd^.data.Instance)^=TDT_SilaIst then
         begin
              inc(counter);


              pvd:=pobj^.ou.FindVariable('NMO_Name');
              if pvd<>nil then
                              name:=pgdbstring(pvd.data.Instance)^;
              zf.initxywh('EMTREE',@mainformn,100,100,500,500,false);
              treecontrol.initxywh('asas',@zf,500,0,500,45,false);
              treecontrol.align:=al_client;

              gdbgetmem({$IFDEF DEBUGBUILD}'{E1158636-E1BD-49B8-BFB2-25723FC26625}',{$ENDIF}pointer(root),sizeof(GDBEmSEPDeviceNode));
              root^.initnul;
              root^.NodeName:=name;


              EM_SEP_build_tree(cman,root^.SubNode,pobj);
              treecontrol.tree.AddNode(root);

              treecontrol.Sync;
              treecontrol.Show;zf.Show;



         end;
    end;
  pobj:=drawings.GetCurrentROOT.ObjArray.iterate(ir);
  until (pobj=nil)or(counter<>0);
  end;

  if counter=0 then
                   TMWOHistoryOut('Выбери объект(ы) источник энергии!')
               else
                   EM_SEP_build_graphix(cman,root^.SubNode);
  cman.done;
  //treecontrol.done;
end;*)
procedure KIP_CDBuild_com.Command(Operands:TCommandOperands);
var
    psd:PSelectedObjDesc;
    ir:itrec;
    {pdev,}pnevdev:PGDBObjDevice;
    PBH:PGDBObjBlockdef;
    currentcoord:GDBVertex;
    t_matrix:DMatrix4D;
    pobj,pcobj:PGDBObjEntity;
    ir2:itrec;
    pvd:pvardesk;
    dn:tdevname;
    dna:devnamearray;
    i:integer;
    DC:TDrawContext;
    pentvarext:PTVariablesExtender;
begin
     currentcoord:=nulvertex;
     dc:=drawings.GetCurrentDWG^.CreateDrawingRC;
     drawings.GetCurrentDWG^.AddBlockFromDBIfNeed('HEAD_CONNECTIONDIAGRAM');
     PBH:=drawings.GetCurrentDWG^.BlockDefArray.getblockdef('HEAD_CONNECTIONDIAGRAM');
     if pbh=nil then
                    exit;
     if not PBH.Formated then
                             PBH.FormatEntity(drawings.GetCurrentDWG^,dc);
     dna:=devnamearray.Create;
     psd:=drawings.GetCurrentDWG^.SelObjArray.beginiterate(ir);
     if psd<>nil then
     repeat
           if psd^.objaddr^.GetObjType=GDBDeviceID then
           begin
                pentvarext:=psd^.objaddr^.GetExtension(typeof(TVariablesExtender));
                //pvd:=PTObjectUnit(psd^.objaddr^.ou.Instance)^.FindVariable('DESC_MountingSite');
                pvd:=pentvarext^.entityunit.FindVariable({'DESC_MountingSite'}'NMO_Name');
                if pvd<>nil then
                                dn.name:=pvd.data.PTD.GetValueAsString(pvd.data.Instance)
                            else
                                dn.name:='';
                dn.pdev:=pointer(psd^.objaddr);
                dna.PushBack(dn);
           end;
           psd:=drawings.GetCurrentDWG^.SelObjArray.iterate(ir);
     until psd=nil;

     if dna.Size=0 then
     begin
          ZCMsgCallBackInterface.TextMessage(rscmSelDevsBeforeComm,TMWOHistoryOut);
     end
     else
     begin
     devnamesort.Sort(dna,dna.Size);
     t_matrix:=uzegeometry.CreateTranslationMatrix(createvertex(0,15,0));


     for i:=0 to dna.Size-1 do
       begin
            dn:=dna[i];

            pointer(pnevdev):=dn.pdev^.Clone(@drawings.GetCurrentDWG.ConstructObjRoot);

            pnevdev.Local.P_insert:=currentcoord;
            pnevdev.Local.Basis.oz:=xy_Z_Vertex;
            pnevdev.Local.Basis.ox:=_X_yzVertex;
            pnevdev.Local.Basis.oy:=x_Y_zVertex;
            pnevdev.rotate:=0;

            //pnevdev^.BuildGeometry(drawings.GetCurrentDWG^);
            //pnevdev^.BuildVarGeometry(drawings.GetCurrentDWG^);
            pnevdev^.formatEntity(drawings.GetCurrentDWG^,dc);

            //PBH^.ObjArray.clonetransformedentityto(@pnevdev^.VarObjArray,pnevdev,t_matrix);
                 pobj:=PBH.ObjArray.beginiterate(ir2);
                 if pobj<>nil then
                 repeat
                       pcobj:=pobj.Clone(pnevdev);
                       //pobj.FormatEntity(drawings.GetCurrentDWG^);
                       pcobj.transformat(pobj,@t_matrix);
                       //pcobj.ReCalcFromObjMatrix;
                       if pcobj^.IsHaveLCS then
                                             pcobj^.FormatEntity(drawings.GetCurrentDWG^,dc);
                       pcobj^.FormatEntity(drawings.GetCurrentDWG^,dc);
                       pnevdev^.VarObjArray.AddPEntity(pcobj^);
                       pobj:=PBH.ObjArray.iterate(ir2);
                 until pobj=nil;



            pnevdev^.formatEntity(drawings.GetCurrentDWG^,dc);

            drawings.GetCurrentDWG^.ConstructObjRoot.ObjArray.AddPEntity(pnevdev^);
            currentcoord.x:=currentcoord.x+45;

            //drawings.GetCurrentROOT.ObjArray.ObjTree.CorrectNodeTreeBB(pb);


       end;
     {psd:=drawings.GetCurrentDWG^.SelObjArray.beginiterate(ir);
     if psd<>nil then
     repeat
           if psd^.objaddr^.GetObjType=GDBDeviceID then
           begin
                pointer(pnevdev):=psd^.objaddr^.Clone(@drawings.GetCurrentDWG.ConstructObjRoot);

                pnevdev.Local.P_insert:=currentcoord;
                pnevdev.Local.Basis.oz:=xy_Z_Vertex;

                pnevdev^.BuildGeometry(drawings.GetCurrentDWG^);
                pnevdev^.BuildVarGeometry(drawings.GetCurrentDWG^);
                pnevdev^.formatEntity(drawings.GetCurrentDWG^);

                //PBH^.ObjArray.clonetransformedentityto(@pnevdev^.VarObjArray,pnevdev,t_matrix);
                     pobj:=PBH.ObjArray.beginiterate(ir2);
                     if pobj<>nil then
                     repeat
                           pcobj:=pobj.Clone(pnevdev);
                           //pobj.FormatEntity(drawings.GetCurrentDWG^);
                           pcobj.transformat(pobj,@t_matrix);
                           //pcobj.ReCalcFromObjMatrix;
                           if pcobj^.IsHaveLCS then
                                                 pcobj^.FormatEntity(drawings.GetCurrentDWG^);
                           pcobj^.FormatEntity(drawings.GetCurrentDWG^);
                           pnevdev^.VarObjArray.add(@pcobj);
                           pobj:=PBH.ObjArray.iterate(ir2);
                     until pobj=nil;



                pnevdev^.formatEntity(drawings.GetCurrentDWG^);

                drawings.GetCurrentDWG^.ConstructObjRoot.ObjArray.add(addr(pnevdev));
                currentcoord.x:=currentcoord.x+45;

                //drawings.GetCurrentROOT.ObjArray.ObjTree.CorrectNodeTreeBB(pb);

           end;
     psd:=drawings.GetCurrentDWG^.SelObjArray.iterate(ir);
     until psd=nil;}

     end;
     dna.Destroy;
end;

procedure KIP_LugTableBuild_com.Command(Operands:TCommandOperands);
var
    psd:PSelectedObjDesc;
    ir:itrec;
    {pdev,}pnevdev:PGDBObjDevice;
    PBH:PGDBObjBlockdef;
    currentcoord:GDBVertex;
    t_matrix:DMatrix4D;
    pobj,pcobj:PGDBObjEntity;
    ir2:itrec;
    pvd:pvardesk;
    dn:tdevname;
    dna:devnamearray;
    i:integer;
    DC:TDrawContext;
    pentvarext:PTVariablesExtender;
begin
     currentcoord:=nulvertex;
     dc:=drawings.GetCurrentDWG^.CreateDrawingRC;
     drawings.GetCurrentDWG^.AddBlockFromDBIfNeed('KIP_LUGTABLEELEMENT');
     PBH:=drawings.GetCurrentDWG^.BlockDefArray.getblockdef('KIP_LUGTABLEELEMENT');
     if pbh=nil then
                    exit;
     if not PBH.Formated then
                             PBH.FormatEntity(drawings.GetCurrentDWG^,dc);
     dna:=devnamearray.Create;
     psd:=drawings.GetCurrentDWG^.SelObjArray.beginiterate(ir);
     if psd<>nil then
     repeat
           if psd^.objaddr^.GetObjType=GDBDeviceID then
           begin
                pentvarext:=psd^.objaddr^.GetExtension(typeof(TVariablesExtender));
                //pvd:=PTObjectUnit(psd^.objaddr^.ou.Instance)^.FindVariable('DESC_MountingSite');
                pvd:=pentvarext^.entityunit.FindVariable({'DESC_MountingSite'}'NMO_Name');
                if pvd<>nil then
                                dn.name:=pvd.data.PTD.GetValueAsString(pvd.data.Instance)
                            else
                                dn.name:='';
                dn.pdev:=pointer(psd^.objaddr);
                dna.PushBack(dn);
           end;
           psd:=drawings.GetCurrentDWG^.SelObjArray.iterate(ir);
     until psd=nil;

     if dna.Size=0 then
     begin
          ZCMsgCallBackInterface.TextMessage(rscmSelDevsBeforeComm,TMWOHistoryOut);
     end
     else
     begin
     devnamesort.Sort(dna,dna.Size);
     t_matrix:=uzegeometry.CreateTranslationMatrix(createvertex(50,12,0));


     for i:=0 to dna.Size-1 do
       begin
            dn:=dna[i];

            pointer(pnevdev):=dn.pdev^.Clone(@drawings.GetCurrentDWG.ConstructObjRoot);

            pnevdev.Local.P_insert:=currentcoord;
            pnevdev.Local.Basis.oz:=xy_Z_Vertex;
            pnevdev.Local.Basis.ox:=_X_yzVertex;
            pnevdev.Local.Basis.oy:=x_Y_zVertex;
            pnevdev.rotate:=0;

            //pnevdev^.BuildGeometry(drawings.GetCurrentDWG^);
            //pnevdev^.BuildVarGeometry(drawings.GetCurrentDWG^);
            pnevdev^.formatEntity(drawings.GetCurrentDWG^,dc);

            //PBH^.ObjArray.clonetransformedentityto(@pnevdev^.VarObjArray,pnevdev,t_matrix);
                 pobj:=PBH.ObjArray.beginiterate(ir2);
                 if pobj<>nil then
                 repeat
                       pcobj:=pobj.Clone(pnevdev);
                       //pobj.FormatEntity(drawings.GetCurrentDWG^);
                       pcobj.transformat(pobj,@t_matrix);
                       //pcobj.ReCalcFromObjMatrix;
                       if pcobj^.IsHaveLCS then
                                             pcobj^.FormatEntity(drawings.GetCurrentDWG^,dc);
                       pcobj^.FormatEntity(drawings.GetCurrentDWG^,dc);
                       pnevdev^.VarObjArray.AddPEntity(pcobj^);
                       pobj:=PBH.ObjArray.iterate(ir2);
                 until pobj=nil;



            pnevdev^.formatEntity(drawings.GetCurrentDWG^,dc);

            drawings.GetCurrentDWG^.ConstructObjRoot.ObjArray.AddPEntity(pnevdev^);
            currentcoord.y:=currentcoord.y-24;

            //drawings.GetCurrentROOT.ObjArray.ObjTree.CorrectNodeTreeBB(pb);


       end;
     {psd:=drawings.GetCurrentDWG^.SelObjArray.beginiterate(ir);
     if psd<>nil then
     repeat
           if psd^.objaddr^.GetObjType=GDBDeviceID then
           begin
                pointer(pnevdev):=psd^.objaddr^.Clone(@drawings.GetCurrentDWG.ConstructObjRoot);

                pnevdev.Local.P_insert:=currentcoord;
                pnevdev.Local.Basis.oz:=xy_Z_Vertex;

                pnevdev^.BuildGeometry(drawings.GetCurrentDWG^);
                pnevdev^.BuildVarGeometry(drawings.GetCurrentDWG^);
                pnevdev^.formatEntity(drawings.GetCurrentDWG^);

                //PBH^.ObjArray.clonetransformedentityto(@pnevdev^.VarObjArray,pnevdev,t_matrix);
                     pobj:=PBH.ObjArray.beginiterate(ir2);
                     if pobj<>nil then
                     repeat
                           pcobj:=pobj.Clone(pnevdev);
                           //pobj.FormatEntity(drawings.GetCurrentDWG^);
                           pcobj.transformat(pobj,@t_matrix);
                           //pcobj.ReCalcFromObjMatrix;
                           if pcobj^.IsHaveLCS then
                                                 pcobj^.FormatEntity(drawings.GetCurrentDWG^);
                           pcobj^.FormatEntity(drawings.GetCurrentDWG^);
                           pnevdev^.VarObjArray.add(@pcobj);
                           pobj:=PBH.ObjArray.iterate(ir2);
                     until pobj=nil;



                pnevdev^.formatEntity(drawings.GetCurrentDWG^);

                drawings.GetCurrentDWG^.ConstructObjRoot.ObjArray.add(addr(pnevdev));
                currentcoord.x:=currentcoord.x+45;

                //drawings.GetCurrentROOT.ObjArray.ObjTree.CorrectNodeTreeBB(pb);

           end;
     psd:=drawings.GetCurrentDWG^.SelObjArray.iterate(ir);
     until psd=nil;}

     end;
     dna.Destroy;
end;

procedure EM_SRBUILD_com.Command(Operands:TCommandOperands);
var
      pobj: pGDBObjEntity;
      pgroupdev:pGDBObjDevice;
      ir,ir2,ir_inNodeArray:itrec;
      counter:integer;
      //tcd:TCopyObjectDesc;
      pvd:pvardesk;
      name,{material,}potrname{,potrmaterial}:GDBString;
      p,pust,i,iust,cosf:PGDBDouble;
      potrpust,potriust,potrpr,potrir,potrpv,potrp,potri,potrks,potrcos,sumpcos,sumpotrp,sumpotri:GDBDouble;
      cman:TCableManager;
      pcabledesk:PTCableDesctiptor;
      node:PGDBObjDevice;
      pt:PGDBObjTable;
      psl,psfirstline:PTZctnrVectorGDBString;
      //first:boolean;
      s:gdbstring;
      TCP:TCodePage;
      DC:TDrawContext;
      pentvarext,pgroupdevvarext,pcablevarext:PTVariablesExtender;
begin
    TCP:=CodePage;
    CodePage:=CP_win;
  counter:=0;
  cman.init;
  cman.build;
             drawings.GetCurrentDWG.wa.SetMouseMode((MGet3DPoint) or (MMoveCamera) or (MRotateCamera));

  pobj:=drawings.GetCurrentROOT.ObjArray.beginiterate(ir);
  if pobj<>nil then
  begin
  repeat
    if pobj.selected then
    if pobj.GetObjType=GDBDeviceID then
    begin
         pentvarext:=pobj^.GetExtension(typeof(TVariablesExtender));
         //pvd:=PTObjectUnit(pobj^.ou.Instance)^.FindVariable('Device_Type');
         pvd:=pentvarext^.entityunit.FindVariable('Device_Type');
         if pvd<>nil then
         if PTDeviceType(pvd^.data.Instance)^=TDT_SilaIst then
         begin


              inc(counter);

              name:='Без имени';
              //material:='Без имени';
              pvd:=pentvarext^.entityunit.FindVariable('NMO_Name');
              if pvd<>nil then
                              name:=pgdbstring(pvd.data.Instance)^;
              pvd:=pentvarext^.entityunit.FindVariable('DB_link');
              //if pvd<>nil then
              //                material:=pgdbstring(pvd.data.Instance)^;
              ZCMsgCallBackInterface.TextMessage('Найден объект источник энергии "'+name+'"',TMWOHistoryOut);

              p:=nil;pust:=nil;i:=nil;iust:=nil;cosf:=nil;
              sumpcos:=0;

              pvd:=pentvarext^.entityunit.FindVariable('Power');
              if pvd<>nil then
                              p:=pvd.data.Instance;
              pvd:=pentvarext^.entityunit.FindVariable('PowerUst');
              if pvd<>nil then
                              pust:=pvd.data.Instance;
              pvd:=pentvarext^.entityunit.FindVariable('Current');
              if pvd<>nil then
                              i:=pvd.data.Instance;
              pvd:=pentvarext^.entityunit.FindVariable('CurrentUst');
              if pvd<>nil then
                              iust:=pvd.data.Instance;
              pvd:=pentvarext^.entityunit.FindVariable('CosPHI');
              if pvd<>nil then
                              cosf:=pvd.data.Instance;
              if (p<>nil)and(pust<>nil)and(i<>nil)and(iust<>nil) then
              begin

                     GDBGetMem({$IFDEF DEBUGBUILD}'{76F46B7D-CAFA-4509-8B65-8759292D8709}',{$ENDIF}pointer(pt),sizeof(GDBObjTable));
                     pt^.initnul;
                     pt^.ptablestyle:=drawings.GetCurrentDWG.TableStyleTable.getAddres('ShRaspr');
                     pt^.tbl.free;
                     //first:=true;
                     {$ifndef GenericsContainerNotFinished}psfirstline:=pointer(pt^.tbl.CreateObject);{$endif}
                     psfirstline.init(16);

                   ZCMsgCallBackInterface.TextMessage('Текущие значения Pрасч='+floattostr(p^)+'; Iрасч='+floattostr(i^)+'; Pуст='+floattostr(pust^)+'; Iуст='+floattostr(iust^)+' будут пересчитаны',TMWOHistoryOut);
                   p^:=0;
                   pust^:=0;
                   i^:=0;
                   iust^:=0;
                   pcabledesk:=cman.beginiterate(ir2);
                   if pcabledesk<>nil then
                   repeat
                         sumpotrp:=0;
                         sumpotri:=0;
                         potrname:='';
                         if pcabledesk^.StartDevice.bp.ListPos.Owner=pointer(pobj) then
                         begin
                              ZCMsgCallBackInterface.TextMessage('  Найдена групповая линия "'+pcabledesk^.Name+'"',TMWOHistoryOut);

                              potrpust:=0;
                              potriust:=0;

                              {node:=}pcabledesk^.Devices.beginiterate(ir_inNodeArray);
                              node:=pcabledesk^.Devices.iterate(ir_inNodeArray);
                              if node<>nil then
                              repeat
                                    pgroupdev:=pointer(node.bp.ListPos.Owner);
                                    if pgroupdev<>nil then
                                    begin
                                         pgroupdevvarext:=pgroupdev^.GetExtension(typeof(TVariablesExtender));
                                         pvd:=pgroupdevvarext^.entityunit.FindVariable('Device_Type');
                                         if pvd<>nil then
                                         begin
                                              case PTDeviceType(pvd^.data.Instance)^ of
                                                   TDT_SilaPotr:
                                                                begin
                                                                      //potrmaterial:='Без имени';
                                                                      pvd:=pgroupdevvarext^.entityunit.FindVariable('NMO_Name');
                                                                      if pvd<>nil then
                                                                                      begin
                                                                                           if potrname='' then
                                                                                                              potrname:=Uni2CP(pgdbstring(pvd.data.Instance)^)
                                                                                                          else
                                                                                                              potrname:=potrname+'+ '+Uni2CP(pgdbstring(pvd.data.Instance)^);
                                                                                      end;
                                                                      pvd:=pgroupdevvarext^.entityunit.FindVariable('DB_link');
                                                                      //if pvd<>nil then
                                                                      //                potrmaterial:=pgdbstring(pvd.data.Instance)^;
                                                                      potrpv:=1;
                                                                      pvd:=pgroupdevvarext^.entityunit.FindVariable('PV');
                                                                      if pvd<>nil then
                                                                                      potrpv:=pgdbdouble(pvd.data.Instance)^;
                                                                      potrp:=0;
                                                                      pvd:=pgroupdevvarext^.entityunit.FindVariable('Power');
                                                                      if pvd<>nil then
                                                                                      potrp:=pgdbdouble(pvd.data.Instance)^;
                                                                      potri:=0;
                                                                      pvd:=pgroupdevvarext^.entityunit.FindVariable('Current');
                                                                      if pvd<>nil then
                                                                                      potri:=pgdbdouble(pvd.data.Instance)^;
                                                                      potrks:=1;
                                                                      pvd:=pgroupdevvarext^.entityunit.FindVariable('Ks');
                                                                      if pvd<>nil then
                                                                                      potrks:=pgdbdouble(pvd.data.Instance)^;
                                                                      potrcos:=1;
                                                                      pvd:=pgroupdevvarext^.entityunit.FindVariable('CosPHI');
                                                                      if pvd<>nil then
                                                                                      potrcos:=pgdbdouble(pvd.data.Instance)^;

                                                                      pust^:=pust^+potrp;
                                                                      iust^:=iust^+potri;

                                                                      sumpcos:=sumpcos+potrp*potrcos;

                                                                      potrpust:=potrpust+potrp;
                                                                      potriust:=potriust+potri;

                                                                      potrp:=potrp*potrks*sqrt(potrpv);
                                                                      potri:=potri*potrks*sqrt(potrpv);

                                                                      sumpotrp:=sumpotrp+potrp;
                                                                      sumpotri:=sumpotri+potri;

                                                                      p^:=p^+potrp;
                                                                      i^:=i^+potri;
                                                                      ZCMsgCallBackInterface.TextMessage('    Найден объект потребитель энергии "'+potrname+'"; Pрасч='+floattostr(potrp)+'; Iрасч='+floattostr(potri),TMWOHistoryOut);




//                                                                      psl:=pointer(pt^.tbl.CreateObject);
//                                                                      psl.init(16);
//                                                                      if first then
//                                                                                   begin
//                                                                                        s:=name;
//                                                                                        psl.add(@s);
//                                                                                        first:=false;
//                                                                                   end
//                                                                               else
//                                                                                   begin
//                                                                                        s:='';
//                                                                                        psl.add(@s);
//                                                                                   end;
//                                                                      s:='';
//                                                                      psl.add(@s);
//                                                                      psl.add(@s);
//                                                                      psl.add(@s);
//                                                                      psl.add(@s);
//                                                                      s:='1';
//                                                                      psl.add(@s);
//                                                                      s:=pcabledesk^.Name;
//                                                                      psl.add(@s);
//                                                                      s:='';
//                                                                      psl.add(@s);
//                                                                      s:='qwer';
//                                                                      pvd:=pcabledesk^.StartSegment^.ou.FindVariable('DB_link');
//                                                                      if pvd<>nil then
//                                                                                      s:=pgdbstring(pvd.data.Instance)^;
//                                                                      pvd:=pgroupdev^.ou.FindVariable('DB_link');
//                                                                      psl.add(@s);
//                                                                      s:=floattostr(pcabledesk^.length);
//                                                                      psl.add(@s);
//                                                                      s:='';
//                                                                      psl.add(@s);
//                                                                      s:='';
//                                                                      psl.add(@s);
//                                                                      s:=potrname;
//                                                                      psl.add(@s);
//                                                                      s:=floattostr(roundto(sumpotrp,-2));
//                                                                      psl.add(@s);
//                                                                      s:=floattostr(roundto(sumpotri,-2));
//                                                                      psl.add(@s);
//                                                                      s:='название';
//                                                                      psl.add(@s);

                                                                end;
                                                   TDT_SilaIst:
                                                                begin
                                                                      //potrmaterial:='Без имени';
                                                                      pvd:=pgroupdevvarext^.entityunit.FindVariable('NMO_Name');
                                                                      if pvd<>nil then
                                                                                      begin
                                                                                           if potrname='' then
                                                                                                              potrname:=Uni2CP(pgdbstring(pvd.data.Instance)^)
                                                                                                          else
                                                                                                              potrname:=potrname+'+ '+Uni2CP(pgdbstring(pvd.data.Instance)^);
                                                                                      end;
                                                                      pvd:=pgroupdevvarext^.entityunit.FindVariable('DB_link');
                                                                      //if pvd<>nil then
                                                                      //                potrmaterial:=pgdbstring(pvd.data.Instance)^;
                                                                      potrp:=0;
                                                                      pvd:=pgroupdevvarext^.entityunit.FindVariable('PowerUst');
                                                                      if pvd<>nil then
                                                                                      potrp:=pgdbdouble(pvd.data.Instance)^;
                                                                      potri:=0;
                                                                      pvd:=pgroupdevvarext^.entityunit.FindVariable('CurrentUst');
                                                                      if pvd<>nil then
                                                                                      potri:=pgdbdouble(pvd.data.Instance)^;
                                                                      potrpr:=0;
                                                                      pvd:=pgroupdevvarext^.entityunit.FindVariable('Power');
                                                                      if pvd<>nil then
                                                                                      potrpr:=pgdbdouble(pvd.data.Instance)^;
                                                                      potrir:=0;
                                                                      pvd:=pgroupdevvarext^.entityunit.FindVariable('Current');
                                                                      if pvd<>nil then
                                                                                      potrir:=pgdbdouble(pvd.data.Instance)^;
                                                                      potrcos:=1;
                                                                      pvd:=pgroupdevvarext^.entityunit.FindVariable('CosPHI');
                                                                      if pvd<>nil then
                                                                                      potrcos:=pgdbdouble(pvd.data.Instance)^;

                                                                      pust^:=pust^+potrp;
                                                                      iust^:=iust^+potri;

                                                                      sumpcos:=sumpcos+potrp*potrcos;

                                                                      potrp:=potrpr;
                                                                      potri:=potrir;

                                                                      potrpust:=potrpust+potrp;
                                                                      potriust:=potriust+potri;

                                                                      sumpotrp:=sumpotrp+potrp;
                                                                      sumpotri:=sumpotri+potri;

                                                                      p^:=p^+potrp;
                                                                      i^:=i^+potri;
                                                                      ZCMsgCallBackInterface.TextMessage('    Найден объект распределитель энергии "'+potrname+'"; Pрасч='+floattostr(potrp)+'; Iрасч='+floattostr(potri),TMWOHistoryOut);
                                                                 end;
                                              end;
                                         end;
                                         {pv:=1;
                                         pvd:=pobj^.ou.FindVariable('PV');
                                         if pvd<>nil then
                                         pv:=pgdbdouble(pvd.data.Instance)^;}
                                    end;



                                    node:=pcabledesk^.Devices.iterate(ir_inNodeArray);
                              until node=nil;
                  {$ifndef GenericsContainerNotFinished} psl:=pointer(pt^.tbl.CreateObject);{$endif}
                  psl.init(16);
                  {if first then
                               begin
                                    s:=name;
                                    psl.add(@s);
                                    first:=false;
                               end
                           else}
                               begin
                                    s:='';
                                    psl.PushBackData(s);
                               end;
                  s:='';
                  psl.PushBackData(s);
                  psl.PushBackData(s);
                  psl.PushBackData(s);
                  psl.PushBackData(s);
                  s:='1';
                  psl.PushBackData(s);
                  s:=Uni2CP(pcabledesk^.Name);
                  psl.PushBackData(s);
                  s:='';
                  psl.PushBackData(s);
                  s:='qwer';
                  pcablevarext:=pcabledesk^.StartSegment^.GetExtension(typeof(TVariablesExtender));
                  pvd:=pcablevarext^.entityunit.FindVariable('DB_link');
                  if pvd<>nil then
                                  s:=Uni2CP(pgdbstring(pvd.data.Instance)^);
                  //pvd:=pgroupdev^.ou.FindVariable('DB_link');
                  psl.PushBackData(s);
                  s:=floattostr(pcabledesk^.length);
                  psl.PushBackData(s);
                  s:='';
                  psl.PushBackData(s);
                  s:='';
                  psl.PushBackData(s);
                  s:=potrname;
                  psl.PushBackData(s);
                  s:=floattostr(roundto({sumpotrp}potrpust,-2));
                  psl.PushBackData(s);
                  s:=floattostr(roundto({sumpotri}potriust,-2));
                  psl.PushBackData(s);
                  s:=Uni2CP('Потребитель');
                  psl.PushBackData(s);

                         end;

                        pcabledesk:=cman.iterate(ir2);
                   until pcabledesk=nil;


              if cosf<>nil then
              cosf^:=sumpcos/pust^;

                  s:=Uni2CP(name);
                  psfirstline.PushBackData(s);
                  s:='';
                  psfirstline.PushBackData(s);
                  psfirstline.PushBackData(s);
                  psfirstline.PushBackData(s);
                  psfirstline.PushBackData(s);
                  s:='1';
                  psfirstline.PushBackData(s);
                  s:='';
                  psfirstline.PushBackData(s);
                  s:='';
                  psfirstline.PushBackData(s);
                  //s:='qwer';
                  psfirstline.PushBackData(s);
                  //s:=floattostr(pcabledesk^.length);
                  psfirstline.PushBackData(s);
                  s:='';
                  psfirstline.PushBackData(s);
                  s:='';
                  psfirstline.PushBackData(s);
                  //s:=potrname;
                  psfirstline.PushBackData(s);
                  s:=floattostr(roundto(p^,-2));
                  psfirstline.PushBackData(s);
                  s:=floattostr(roundto(i^,-2));
                  psfirstline.PushBackData(s);
                  s:=Uni2CP('Ввод');
                  psfirstline.PushBackData(s);


              drawings.CurrentDWG.ConstructObjRoot.ObjArray.AddPEntity(pt^);
              pt^.Build(drawings.GetCurrentDWG^);
              dc:=drawings.CurrentDWG.CreateDrawingRC;
              pt^.FormatEntity(drawings.GetCurrentDWG^,dc);
              end;

         end;
    end;
  pobj:=drawings.GetCurrentROOT.ObjArray.iterate(ir);
  until pobj=nil;
  end;
  if counter=0 then
                   ZCMsgCallBackInterface.TextMessage('Выбери объект(ы) источник энергии!',TMWOHistoryOut);
  cman.done;
  CodePage:=TCP;
end;
constructor El_Wire_com.init;
begin
  inherited init(cn,sa,da);
  dyn:=false;
end;

procedure El_Wire_com.CommandStart;
begin
  inherited CommandStart('');;
  FirstOwner:=nil;
  SecondOwner:=nil;
  OldFirstOwner:=nil;
  drawings.GetCurrentDWG.wa.SetMouseMode((MGet3DPoint) or (MMoveCamera) or (MRotateCamera));
  Prompt('Начало цепи:');
end;

procedure El_Wire_com.CommandCancel;
begin
end;

function El_Wire_com.BeforeClick(wc: GDBvertex; mc: GDBvertex2DI; var button: GDBByte;osp:pos_record): GDBInteger;
var //po:PGDBObjSubordinated;
    Objects:GDBObjOpenArrayOfPV;
    DC:TDrawContext;
begin
  result:=0;
  Objects.init({$IFDEF DEBUGBUILD}'{8BE71BAA-507B-4D6B-BE2C-63693022090C}',{$ENDIF}10);
  if drawings.GetCurrentROOT.FindObjectsInPoint(wc,Objects) then
  begin
       FirstOwner:=pointer(drawings.FindOneInArray(Objects,GDBNetID,true));
  end;
  Objects.Clear;
  Objects.Done;
  (*if osp<>nil then
  begin
       if (PGDBObjEntity(osp^.PGDBObject)<>nil)and(osp^.PGDBObject<>FirstOwner)
       then
       begin
            PGDBObjEntity(osp^.PGDBObject)^.format;
            TMWOHistoryOut(GDBPointer(PGDBObjline(osp^.PGDBObject)^.ObjToGDBString('Found: ','')));
            po:=PGDBObjEntity(osp^.PGDBObject)^.getowner;
            //FirstOwner:=GDBPointer(po);
       end
  end {else FirstOwner:=oldfirstowner};*)
  if (button and MZW_LBUTTON)<>0 then
  begin
  dc:=drawings.GetCurrentDWG^.CreateDrawingRC;
    Prompt('Вторая точка:');
    New_line := PGDBObjLine(ENTF_CreateLine(@drawings.GetCurrentDWG^.ConstructObjRoot,@drawings.GetCurrentDWG^.ConstructObjRoot.ObjArray,[wc.x,wc.y,wc.z,wc.x,wc.y,wc.z]));
    zcSetEntPropFromCurrentDrawingProp(New_line);
    //New_line := GDBPointer(drawings.GetCurrentDWG.ConstructObjRoot.ObjArray.CreateObj(GDBLineID{,drawings.GetCurrentROOT}));
    //GDBObjLineInit(drawings.GetCurrentROOT,New_line,drawings.GetCurrentDWG.LayerTable.GetCurrentLayer,sysvar.dwg.DWG_CLinew^,wc,wc);
    New_line^.Formatentity(drawings.GetCurrentDWG^,dc);
  end
end;

function El_Wire_com.AfterClick(wc: GDBvertex; mc: GDBvertex2DI; var button: GDBByte;osp:pos_record): GDBInteger;
var //po:PGDBObjSubordinated;
    mode:GDBInteger;
    TempNet:PGDBObjNet;
    //nn:GDBString;
    pvd{,pvd2}:pvardesk;
    nni:gdbinteger;
    Objects:GDBObjOpenArrayOfPV;
    DC:TDrawContext;
    ptempnetvarext,pfirstownervarext,psecondownervarext:PTVariablesExtender;
begin
  dc:=drawings.GetCurrentDWG^.CreateDrawingRC;
  New_line^.vp.Layer :=drawings.GetCurrentDWG.GetCurrentLayer;
  drawings.standardization(New_line,GDBNetID);
  New_line^.vp.lineweight := sysvar.dwg.DWG_CLinew^;
  New_line.CoordInOCS.lEnd:= wc;
  New_line^.Formatentity(drawings.GetCurrentDWG^,dc);
  //po:=nil;
  if (button and MZW_LBUTTON)<>0 then
                                     button:=button;
  Objects.init({$IFDEF DEBUGBUILD}'{8BE71BAA-507B-4D6B-BE2C-63693022090C}',{$ENDIF}10);
  if drawings.GetCurrentROOT.FindObjectsInPoint(wc,Objects) then
  begin
       SecondOwner:=pointer(drawings.FindOneInArray(Objects,GDBNetID,true));
  end;
  Objects.Clear;
  Objects.Done;

  if osp<>nil then
  begin
       if (PGDBObjEntity(osp^.PGDBObject)<>nil)and(osp^.PGDBObject<>SecondOwner)
       then
       begin
            PGDBObjEntity(osp^.PGDBObject)^.formatentity(drawings.GetCurrentDWG^,dc);
            ZCMsgCallBackInterface.TextMessage(PGDBObjline(osp^.PGDBObject)^.ObjToGDBString('Found: ',''),TMWOHistoryOut);
            //po:=PGDBObjEntity(osp^.PGDBObject)^.getowner;
            //SecondOwner:=GDBPointer(po);
       end
  end {else SecondOwner:=nil};
  //pl^.RenderFeedback;
  if (button and MZW_LBUTTON)<>0 then
  begin
    New_line^.RenderFeedback(drawings.GetCurrentDWG.pcamera^.POSCOUNT,drawings.GetCurrentDWG.pcamera^,drawings.GetCurrentDWG^.myGluProject2,dc);
    if FirstOwner<>nil then
    begin
         if FirstOwner^.EubEntryType<>se_ElectricalWires then FirstOwner:=nil;
    end;
    if SecondOwner<>nil then
    begin
         if SecondOwner^.EubEntryType<>se_ElectricalWires then SecondOwner:=nil;
    end;
    mode:=0;
    if (FirstOwner=nil) and (SecondOwner=nil) then mode:=0
    else if (FirstOwner<>nil) and (SecondOwner<>nil) then begin if FirstOwner<>SecondOwner then mode:=2 else begin mode:=1;SecondOwner:=nil; end;end
    else if (FirstOwner<>nil) then mode:=1
    else if (SecondOwner<>nil) then begin mode:=1; FirstOwner:=SecondOwner;SecondOwner:=nil; end;
    repeat
    case mode of
          0:begin
                 TempNet:=nil;
                 GDBGetMem({$IFDEF DEBUGBUILD}'{C92353C3-EA26-48A9-A47F-89F7723E3D16}',{$ENDIF}GDBPointer(TempNet),sizeof(GDBObjNet));
                 TempNet^.initnul(nil);
                 zcSetEntPropFromCurrentDrawingProp(TempNet);
                 drawings.standardization(TempNet,GDBNetID);
                 ptempnetvarext:=TempNet^.GetExtension(typeof(TVariablesExtender));
                 ptempnetvarext^.entityunit.copyfrom(units.findunit(SupportPath,InterfaceTranslate,'trace'));
                 pvd:=ptempnetvarext^.entityunit.FindVariable('NMO_Suffix');
                 pstring(pvd^.data.Instance)^:=inttostr(drawings.GetCurrentDWG.numerator.getnumber(UNNAMEDNET,SysVar.DSGN.DSGN_TraceAutoInc^));
                 pvd:=ptempnetvarext^.entityunit.FindVariable('NMO_Prefix');
                 pstring(pvd^.data.Instance)^:='@';
                 pvd:=ptempnetvarext^.entityunit.FindVariable('NMO_BaseName');
                 pstring(pvd^.data.Instance)^:=UNNAMEDNET;
                 //TempNet^.name:=drawings.numerator.getnamenumber(el_unname_prefix);
                 New_line^.bp.ListPos.Owner:=TempNet;
                 TempNet^.ObjArray.AddPEntity(New_line^);
                 TempNet^.Formatentity(drawings.GetCurrentDWG^,dc);
                 drawings.GetCurrentROOT.AddObjectToObjArray{ObjArray.add}(@TempNet);
                 firstowner:=TempNet;
                 mode:=-1;
            end;
          1:begin
                 New_line^.bp.ListPos.Owner:=FirstOwner;
                 FirstOwner^.ObjArray.AddPEntity(New_line^);
                 //FirstOwner^.Formatentity(drawings.GetCurrentDWG^);
                 FirstOwner.YouChanged(drawings.GetCurrentDWG^);
                 mode:=-1;
            end;
          2:begin
                 //pvd:=SecondOwner.ou.FindVariable('NMO_Name');
                 //pvd2:=firstowner.ou.FindVariable('NMO_Name');
                 nni:=SecondOwner.CalcNewName(SecondOwner,firstowner{pstring(pvd^.data.Instance)^,pstring(pvd2^.data.Instance)^});
                 if {nn<>''}nni<>0 then
                 begin
                 SecondOwner^.MigrateTo(FirstOwner);

                 if nni=1 then
                 begin
                      pfirstownervarext:=FirstOwner^.GetExtension(typeof(TVariablesExtender));
                      pfirstownervarext^.entityunit.free;
                      psecondownervarext:=secondowner^.GetExtension(typeof(TVariablesExtender));
                      psecondownervarext^.entityunit.CopyTo(@pfirstownervarext^.entityunit);
                      //FirstOwner^.Name:=nn;
                 end;

                 New_line^.bp.ListPos.Owner:=FirstOwner;
                 FirstOwner^.ObjArray.AddPEntity(New_line^);
                 //FirstOwner^.Formatentity(drawings.GetCurrentDWG^);
                 FirstOwner.YouChanged(drawings.GetCurrentDWG^);
                 mode:=-1;

                 SecondOwner^.YouDeleted(drawings.GetCurrentDWG^);
                 end
                    else mode:=0;
            end;
    end;
    until mode=-1;
    drawings.GetCurrentROOT.calcbb(dc);
    drawings.GetCurrentDWG.ConstructObjRoot.ObjArray.Count := 0;
    oldfirstowner:=firstowner;
    drawings.GetCurrentDWG.wa.param.lastonmouseobject:=nil;

    drawings.GetCurrentDWG.OnMouseObj.Clear;
    {if assigned( ClrarIfItIsProc)then
    ClrarIfItIsProc(SecondOwner);}

    zcRedrawCurrentDrawing;
    if mode= 2 then commandmanager.executecommandend
               else beforeclick(wc,mc,button,osp);
  end;
  result:=cmd_ok;
end;
function GetEntName(pu:PGDBObjGenericWithSubordinated):GDBString;
var
   pvn:pvardesk;
   pentvarext:PTVariablesExtender;
begin
     result:='';
     pentvarext:=pu^.GetExtension(typeof(TVariablesExtender));
     pvn:=pentvarext^.entityunit.FindVariable('NMO_Name');
     if (pvn<>nil) then
                                      begin
                                           result:=pstring(pvn^.data.Instance)^;
                                      end;
end;
procedure cabcomformat;
var
   s:gdbstring;
   ir_inGDB:itrec;
   currentobj:PGDBObjNet;
begin
  cabcomparam.Traces.Enums.free;
  cabcomparam.PTrace:=nil;

  CurrentObj:=drawings.GetCurrentROOT.ObjArray.beginiterate(ir_inGDB);
  if (CurrentObj<>nil) then
     repeat
           if CurrentObj^.GetObjType=GDBNetID then
           begin
                s:=getentname(CurrentObj);
                if s<>'' then
                begin
                     cabcomparam.Traces.Enums.PushBackData(s);
                     if cabcomparam.Traces.Selected=cabcomparam.Traces.Enums.Count-1 then
                                                                                         cabcomparam.PTrace:=CurrentObj;


                end;
           end;
           CurrentObj:=drawings.GetCurrentROOT.ObjArray.iterate(ir_inGDB);
     until CurrentObj=nil;

  s:='**Напрямую**';
  cabcomparam.Traces.Enums.PushBackData(s);
end;
function _Cable_com_CommandStart(operands:TCommandOperands):TCommandResult;
var
   s:gdbstring;
   ir_inGDB:itrec;
   currentobj:PGDBObjNet;
begin
  p3dpl:=nil;
  drawings.GetCurrentDWG.wa.SetMouseMode((MGet3DPoint) or (MMoveCamera) or (MRotateCamera));

  cabcomparam.Pcable:=nil;
  cabcomparam.PTrace:=nil;
  cabcomparam.Traces.Enums.free;
  //cabcomparam.Traces.Selected:=-1;
  CurrentObj:=drawings.GetCurrentROOT.ObjArray.beginiterate(ir_inGDB);
  if (CurrentObj<>nil) then
     repeat
           if CurrentObj^.GetObjType=GDBNetID then
           begin
                s:=getentname(CurrentObj);
                if s<>'' then
                begin
                     cabcomparam.Traces.Enums.PushBackData(s);
                     if CurrentObj^.Selected then
                     begin
                          cabcomparam.Traces.Selected:=cabcomparam.Traces.Enums.Count-1;
                     end;

                     if cabcomparam.Traces.Selected=cabcomparam.Traces.Enums.Count-1 then
                                                                                         cabcomparam.PTrace:=CurrentObj;


                end;
           end;
           CurrentObj:=drawings.GetCurrentROOT.ObjArray.iterate(ir_inGDB);
     until CurrentObj=nil;

  s:='**Напрямую**';
  cabcomparam.Traces.Enums.PushBackData(s);
  zcShowCommandParams(SysUnit.TypeName2PTD('CommandRTEdObject'),pcabcom);



  ZCMsgCallBackInterface.TextMessage('Первая точка:',TMWOHistoryOut);
  result:=cmd_ok;
end;
Procedure _Cable_com_CommandEnd(_self:pointer);
begin
  if p3dpl<>nil then
  begin
  PTZCADDrawing(drawings.GetCurrentDWG).UndoStack.PushEndMarker;
  if p3dpl^.VertexArrayInOCS.Count<2 then
                                         begin
                                              ZCMsgCallBackInterface.Do_GUIaction(nil,ZMsgID_GUIReturnToDefaultObject);
                                              p3dpl^.YouDeleted(drawings.GetCurrentDWG^);
                                              PTZCADDrawing(drawings.GetCurrentDWG).UndoStack.KillLastCommand;
                                         end;
  end;
  cabcomparam.PCable:=nil;
  cabcomparam.PTrace:=nil;
  //gdbfreemem(pointer(p3dpl));
end;
function _Cable_com_BeforeClick(wc: GDBvertex; mc: GDBvertex2DI; var button: GDBByte;osp:pos_record;mclick:GDBInteger): GDBInteger;
var
   pvd:pvardesk;
   domethod,undomethod:tmethod;
   DC:TDrawContext;
   pcablevarext:PTVariablesExtender;
begin
  result:=mclick;
  if (button and MZW_LBUTTON)<>0 then
  begin
    if p3dpl=nil then
    begin
      dc:=drawings.GetCurrentDWG^.CreateDrawingRC;
    p3dpl := GDBPointer(drawings.GetCurrentDWG.ConstructObjRoot.ObjArray.CreateInitObj(GDBCableID,drawings.GetCurrentROOT));
    //p3dpl := GDBPointer(drawings.GetCurrentROOT.ObjArray.CreateinitObj(GDBCableID,drawings.GetCurrentROOT));
    zcSetEntPropFromCurrentDrawingProp(p3dpl);
    drawings.standardization(p3dpl,GDBCableID);
    //p3dpl^.init(@drawings.GetCurrentDWG.ObjRoot,drawings.LayerTable.GetCurrentLayer, sysvar.dwg.DWG_CLinew^);

    //uunitmanager.units.loadunit(expandpath('*blocks\el\cable.pas'),@p3dpl^.ou);
    pcablevarext:=p3dpl^.GetExtension(typeof(TVariablesExtender));
    pcablevarext^.entityunit.copyfrom(units.findunit(SupportPath,InterfaceTranslate,'cable'));
    //pvd:=p3dpl^.ou.FindVariable('DB_link');
    //pstring(pvd^.data.Instance)^:='Кабель ??';

    {pvd:=p3dpl.ou.FindVariable('NMO_BaseName');
    pstring(pvd^.data.Instance)^:=drawings.numerator.getnamenumber('К');}
    //pvd:=p3dpl.ou.FindVariable('NMO_Prefix');
    //pstring(pvd^.data.Instance)^:='';

    //pvd:=p3dpl.ou.FindVariable('NMO_BaseName');
    //pstring(pvd^.data.Instance)^:='@';

    pvd:=pcablevarext^.entityunit.FindVariable('NMO_Suffix');
    pstring(pvd^.data.Instance)^:=inttostr(drawings.GetCurrentDWG.numerator.getnumber('CableNum',true));
    //p3dpl^.bp.Owner:=@drawings.GetCurrentDWG.ObjRoot;
    //drawings.GetCurrentDWG.ObjRoot.ObjArray.add(addr(p3dpl));
    //GDBobjinsp.setptr(SysUnit.TypeName2PTD('GDBObjCable'),p3dpl);
    p3dpl^.AddVertex(wc);
    p3dpl^.Formatentity(drawings.GetCurrentDWG^,dc);

    PTZCADDrawing(drawings.GetCurrentDWG).UndoStack.PushStartMarker('Create cable');
    SetObjCreateManipulator(domethod,undomethod);
    with PushMultiObjectCreateCommand(PTZCADDrawing(drawings.GetCurrentDWG).UndoStack,tmethod(domethod),tmethod(undomethod),1)^ do
    begin
         AddObject(p3dpl);
         comit;
    end;
    PTZCADDrawing(drawings.GetCurrentDWG).UndoStack.PushStone;
    drawings.GetCurrentDWG.ConstructObjRoot.ObjArray.Count:=0;

    //drawings.GetCurrentROOT.ObjArray.ObjTree.{AddObjectToNodeTree(p3dpl)}CorrectNodeTreeBB(p3dpl);

    cabcomparam.Pcable:=p3dpl;
    //GDBobjinsp.setptr(SysUnit.TypeName2PTD('GDBObjCable'),p3dpl);
    end;
  end
end;
procedure rootbytrace(firstpoint,lastpoint:GDBVertex;PTrace:PGDBObjNet;cable:PGDBObjCable;addfirstpoint:gdbboolean);
var //po:PGDBObjSubordinated;
    //plastw:pgdbvertex;
    tw1,tw2:gdbvertex;
    l1,l2:pgdbobjline;
    pa:GDBPoint3dArray;
    //polydata:tpolydata;
    //domethod,undomethod:tmethod;
begin
  pointer(l1):=PTrace.GetNearestLine(firstpoint);
  pointer(l2):=PTrace.GetNearestLine(lastpoint);
  tw1:=NearestPointOnSegment(firstpoint,l1.CoordInWCS.lBegin,l1.CoordInWCS.lEnd);
  if l1=l2 then
               begin
                    if addfirstpoint then
                    cable^.AddVertex(firstpoint);
                    if not IsPointEqual(tw1,firstpoint) then
                                                        cable^.AddVertex(tw1);
                    tw1:=NearestPointOnSegment(lastpoint,l1.CoordInWCS.lBegin,l1.CoordInWCS.lEnd);
                    if not IsPointEqual(tw1,lastpoint) then
                                                   cable^.AddVertex(tw1);
                    cable^.AddVertex(lastpoint);
                    //l1:=l2;
               end
           else
               begin
                    tw2:=NearestPointOnSegment(lastpoint,l2.CoordInWCS.lBegin,l2.CoordInWCS.lEnd);
                    PTrace.BuildGraf(drawings.GetCurrentDWG^);
                    pa.init({$IFDEF DEBUGBUILD}'{FE5DE449-60C7-4D92-9BA5-FEB937820B96}',{$ENDIF}100);
                    PTrace.graf.FindPath(tw1,tw2,l1,l2,pa);
                    if addfirstpoint then
                    cable^.AddVertex(firstpoint);
                    if not IsPointEqual(tw1,firstpoint) then
                                                        cable^.AddVertex(tw1);
                    pa.copyto(cable.VertexArrayInOCS);
                    //firstpoint:=pgdbvertex(cable^.VertexArrayInWCS.getDataMutable(cable^.VertexArrayInWCS.Count-1))^;
                    if not IsPointEqual(tw2,firstpoint) then
                                                        cable^.AddVertex(tw2);
                    if not IsPointEqual(tw2,lastpoint) then
                                                   cable^.AddVertex(lastpoint);
                    pa.done;
               end;
end;
function RootByMultiTrace(firstpoint,lastpoint:GDBVertex;PTrace:PGDBObjNet;cable:PGDBObjCable;addfirstpoint:gdbboolean):TZctnrVectorPGDBaseObjects;
var //po:PGDBObjSubordinated;
    //plastw:pgdbvertex;
    tw1,tw2:gdbvertex;
    l1,l2:pgdbobjline;
    pa:GDBPoint3dArray;
    pv:pGDBVertex;
    ir:itrec;
    tcable:PGDBObjCable;
    pvd:pvardesk;
    cablecount:integer;
    //polydata:tpolydata;
    //domethod,undomethod:tmethod;
    ptcablevarext,pcablevarext:PTVariablesExtender;
begin
  pointer(l1):=PTrace.GetNearestLine(firstpoint);
  pointer(l2):=PTrace.GetNearestLine(lastpoint);
  tw1:=NearestPointOnSegment(firstpoint,l1.CoordInWCS.lBegin,l1.CoordInWCS.lEnd);
  result.init({$IFDEF DEBUGBUILD}'{C8C93C89-003D-407B-A6F3-2AAA5D12E01D}',{$ENDIF}100);
  if l1=l2 then
               begin
                    if addfirstpoint then
                    cable^.AddVertex(firstpoint);
                    if not IsPointEqual(tw1,firstpoint) then
                                                        cable^.AddVertex(tw1);
                    tw1:=NearestPointOnSegment(lastpoint,l1.CoordInWCS.lBegin,l1.CoordInWCS.lEnd);
                    if not IsPointEqual(tw1,lastpoint) then
                                                   cable^.AddVertex(tw1);
                    cable^.AddVertex(lastpoint);
                    //l1:=l2;
               end
           else
               begin
                    tw2:=NearestPointOnSegment(lastpoint,l2.CoordInWCS.lBegin,l2.CoordInWCS.lEnd);
                    PTrace.BuildGraf(drawings.GetCurrentDWG^);
                    pa.init({$IFDEF DEBUGBUILD}'{FE5DE449-60C7-4D92-9BA5-FEB937820B96}',{$ENDIF}100);
                    PTrace.graf.FindPath(tw1,tw2,l1,l2,pa);
                    if addfirstpoint then
                    cable^.AddVertex(firstpoint);
                    if not IsPointEqual(tw1,firstpoint) then
                                                        cable^.AddVertex(tw1);
                    //pa.copyto(@cable.VertexArrayInOCS);
                    tcable:=cable;
  cablecount:=1;
  pv:=pa.beginiterate(ir);
  if pv<>nil then
  repeat
        if pv^.x<>infinity then
                               tcable.VertexArrayInOCS.PushBackData(pv^)
                           else
                               begin
                                    tcable := AllocCable;
                                    tcable.init(drawings.GetCurrentROOT,nil,0);
                                    //tcable := GDBPointer(drawings.GetCurrentROOT.ObjArray.CreateinitObj(GDBCableID,drawings.GetCurrentROOT));
                                    ptcablevarext:=tcable^.GetExtension(typeof(TVariablesExtender));
                                    pcablevarext:=cable^.GetExtension(typeof(TVariablesExtender));
                                    ptcablevarext^.entityunit.copyfrom(@pcablevarext^.entityunit);
                                    drawings.standardization(tcable,GDBCableID);
                                    pvd:=ptcablevarext^.entityunit.FindVariable('CABLE_Segment');
                                    if pvd<>nil then
                                    PGDBInteger(pvd^.data.Instance)^:=PGDBInteger(pvd^.data.Instance)^+cablecount;
                                    inc(cablecount);
                                    result.PushBackData(tcable);
                               end;
        pv:=pa.iterate(ir);
  until pv=nil;


                    //firstpoint:=pgdbvertex(cable^.VertexArrayInWCS.getDataMutable(cable^.VertexArrayInWCS.Count-1))^;
                    if not IsPointEqual(tw2,firstpoint) then
                                                        tcable^.AddVertex(tw2);
                    if not IsPointEqual(tw2,lastpoint) then
                                                   tcable^.AddVertex(lastpoint);
                    pa.done;
               end;
end;


function _Cable_com_AfterClick(wc: GDBvertex; mc: GDBvertex2DI; var button: GDBByte;osp:pos_record;mclick:GDBInteger): GDBInteger;
var //po:PGDBObjSubordinated;
    plastw:pgdbvertex;
    //tw1,tw2:gdbvertex;
    //l1,l2:pgdbobjline;
    //pa:GDBPoint3dArray;
    polydata:tpolydata;
    domethod,undomethod:tmethod;
    DC:TDrawContext;
begin
  result:=mclick;
  p3dpl^.vp.Layer :=drawings.GetCurrentDWG.GetCurrentLayer;
  p3dpl^.vp.lineweight := sysvar.dwg.DWG_CLinew^;
  drawings.standardization(p3dpl,GDBCableID);
  //p3dpl^.CoordInOCS.lEnd:= wc;
  dc:=drawings.GetCurrentDWG^.CreateDrawingRC;
  if (button and MZW_LBUTTON)<>0 then
  begin
    if cabcomparam.PTrace=nil then
    begin
         {polydata.nearestvertex:=p3dpl^.VertexArrayInWCS.Count;
         polydata.nearestline:=p3dpl^.VertexArrayInWCS.Count;
         polydata.dir:=1;}
         polydata.index:=p3dpl^.VertexArrayInWCS.Count;
         polydata.wc:=wc;
         tmethod(domethod).Code:=pointer(p3dpl.InsertVertex);
         tmethod(domethod).Data:=p3dpl;
         tmethod(undomethod).Code:=pointer(p3dpl.DeleteVertex);
         tmethod(undomethod).Data:=p3dpl;
         with PushCreateTGObjectChangeCommand2(PTZCADDrawing(drawings.GetCurrentDWG).UndoStack,polydata,tmethod(domethod),tmethod(undomethod))^ do
         begin
              comit;
         end;
          {p3dpl^.AddVertex(wc);}
          p3dpl^.Formatentity(drawings.GetCurrentDWG^,dc);
          p3dpl^.RenderFeedback(drawings.GetCurrentDWG.pcamera^.POSCOUNT,drawings.GetCurrentDWG.pcamera^,drawings.GetCurrentDWG^.myGluProject2,dc);
          drawings.GetCurrentROOT.ObjArray.ObjTree.CorrectNodeBoundingBox(p3dpl^);
    end
else begin
          plastw:=p3dpl^.VertexArrayInWCS.getDataMutable(p3dpl^.VertexArrayInWCS.Count-1);

          rootbytrace(plastw^,wc,cabcomparam.PTrace,p3dpl,false);

          (*pointer(l1):=cabcomparam.PTrace.GetNearestLine(plastw^);
          pointer(l2):=cabcomparam.PTrace.GetNearestLine(wc);
          tw1:=NearestPointOnSegment(plastw^,l1.CoordInWCS.lBegin,l1.CoordInWCS.lEnd);
          if l1=l2 then
                       begin
                            if not IsPointEqual(tw1,plastw^) then
                                                                p3dpl^.AddVertex(tw1);
                            tw1:=NearestPointOnSegment(wc,l1.CoordInWCS.lBegin,l1.CoordInWCS.lEnd);
                            if not IsPointEqual(tw1,wc) then
                                                           p3dpl^.AddVertex(tw1);
                            p3dpl^.AddVertex(wc);
                            //l1:=l2;
                       end
                   else
                       begin
                            tw2:=NearestPointOnSegment(wc,l2.CoordInWCS.lBegin,l2.CoordInWCS.lEnd);
                            cabcomparam.PTrace.BuildGraf;
                            pa.init({$IFDEF DEBUGBUILD}'{FE5DE449-60C7-4D92-9BA5-FEB937820B96}',{$ENDIF}100);
                            cabcomparam.PTrace.graf.FindPath(tw1,tw2,l1,l2,pa);
                            if not IsPointEqual(tw1,plastw^) then
                                                                p3dpl^.AddVertex(tw1);
                            pa.copyto(@p3dpl.VertexArrayInOCS);
                            plastw:=p3dpl^.VertexArrayInWCS.getDataMutable(p3dpl^.VertexArrayInWCS.Count-1);
                            if not IsPointEqual(tw2,plastw^) then
                                                                p3dpl^.AddVertex(tw2);
                            if not IsPointEqual(tw2,wc) then
                                                           p3dpl^.AddVertex(wc);
                            pa.done;
                       end;*)
        p3dpl^.Formatentity(drawings.GetCurrentDWG^,dc);
        p3dpl^.RenderFeedback(drawings.GetCurrentDWG.pcamera^.POSCOUNT,drawings.GetCurrentDWG.pcamera^,drawings.GetCurrentDWG^.myGluProject2,dc);
        drawings.GetCurrentROOT.ObjArray.ObjTree.CorrectNodeBoundingBox(p3dpl^);
     end;
    drawings.GetCurrentDWG.ConstructObjRoot.ObjArray.Count := 0;
    result:=1;
    zcRedrawCurrentDrawing;
  end;
end;
function _Cable_com_Hd(mclick:GDBInteger):TCommandResult;
begin
     //mclick:=mclick;//        asdf
     result:=cmd_ok;
end;
//function _Cable_com_Legend(Operands:pansichar):GDBInteger;
//var i: GDBInteger;
//    pv:pGDBObjEntity;
//    ir,irincable,ir_inNodeArray:itrec;
//    filename,cablename,CableMaterial,CableLength,devstart,devend: GDBString;
//    handle:cardinal;
//    pvd,pvds,pvdal:pvardesk;
//    nodeend,nodestart:PTNodeProp;
//
//    line:gdbstring;
//    firstline:boolean;
//    cman:TCableManager;
//begin
//  cman.init;
//  cman.build;
//  cman.done;
//  //exit;
//  if SaveFileDialog(filename,'CSV',CSVFileFilter,'','Сохранить данные...') then
//  begin
//  handle:=FileCreate(filename,fmOpenWrite);
//  line:='Обозначение'+';'+'Материал'+';'+'Длина'+';'+'Начало'+';'+'Конец'+#13#10;
//  FileWrite(handle,line[1],length(line));
//  pv:=drawings.GetCurrentDWG.ObjRoot.ObjArray.beginiterate(ir);
//  if pv<>nil then
//  repeat
//    //if pv^.Selected then
//    if pv^.GetObjType=GDBCableID then
//    begin
//         line:='';
//         pvd:=pv^.ou.FindVariable('NMO_Name');
//         cablename:=pstring(pvd^.data.Instance)^;
//
//         pvd:=pv^.ou.FindVariable('DB_link');
//         CableMaterial:=pstring(pvd^.data.Instance)^;
//
//         pvd:=pv^.ou.FindVariable('AmountD');
//         CableLength:=floattostr(pgdbdouble(pvd^.data.Instance)^);
//
//          firstline:=true;
//          devstart:='Не присоединено';
//          nodestart:=pgdbobjcable(pv)^.NodePropArray.beginiterate(ir_inNodeArray);
//          if nodestart^.DevLink<>nil then
//                                         begin
//                                              pvd:=nodestart^.DevLink^.FindVariable('NMO_Name');
//                                              if pvd<>nil then
//                                                              devstart:=pstring(pvd^.data.Instance)^;
//                                         end;
//          nodeend:=pgdbobjcable(pv)^.NodePropArray.iterate(ir_inNodeArray);
//          repeat
//                devend:='Не присоединено';
//                repeat
//                            if nodeend=nil then system.break;
//                            //nodeend:=pgdbobjcable(pv)^.NodePropArray.iterate(ir_inNodeArray);
//                            if nodeend^.DevLink=nil then
//                            repeat
//                                  nodeend:=pgdbobjcable(pv)^.NodePropArray.iterate(ir_inNodeArray);
//                                  if nodeend=nil then system.break;
//                            until nodeend^.DevLink<>nil;
//                            if nodeend=nil then system.break;
//                            pvd:=nodeend^.DevLink^.FindVariable('NMO_Name');
//                            if pvd=nil then
//                                           nodeend:=pgdbobjcable(pv)^.NodePropArray.iterate(ir_inNodeArray);
//                until pvd<>nil;
//                if nodeend<>nil then
//                                    devend:=pstring(pvd^.data.Instance)^;
//                if firstline then
//                                 line:=cablename+';'+CableMaterial+';'+CableLength+';'+devstart+';'+devend+#13#10
//                             else
//                                 line:={cablename+}';'+{CableMaterial+}';'+{CableLength+}';'+devstart+';'+devend+#13#10;
//                FileWrite(handle,line[1],length(line));
//                firstline:=false;
//                devstart:=devend;
//                nodeend:=pgdbobjcable(pv)^.NodePropArray.iterate(ir_inNodeArray);
//          until nodeend=nil;
//         ZCMsgCallBackInterface.TextMessage(cablename+' '+CableMaterial+' '+CableLength);
//
//
//    end;
//  pv:=drawings.GetCurrentDWG.ObjRoot.ObjArray.iterate(ir);
//  until pv=nil;
//  redrawoglwnd;
//  FileClose(handle);
//  end;
//  result:=cmd_ok;
//end;
function _Cable_com_Legend(operands:TCommandOperands):TCommandResult;
var //i: GDBInteger;
    pv:PTCableDesctiptor;
    ir,{irincable,}ir_inNodeArray:itrec;
    filename,cablename,CableMaterial,CableLength,devstart,devend,puredevstart: GDBString;
    handle:cardinal;
    pvd{,pvds,pvdal}:pvardesk;
    nodeend,nodestart:PGDBObjDevice;

    line,s:gdbstring;
    firstline:boolean;
    cman:TCableManager;
    pt:PGDBObjTable;
    psl{,psfirstline}:PTZctnrVectorGDBString;

    eq:pvardesk;
    DC:TDrawContext;
    pstartsegmentvarext:PTVariablesExtender;
begin
  filename:='';
  if SaveFileDialog(filename,'CSV',CSVFileFilter,'','Сохранить данные...') then
  begin
  DefaultFormatSettings.DecimalSeparator := ',';
  cman.init;
  cman.build;
  handle:=FileCreate(UTF8ToSys(filename),fmOpenWrite);
  line:=Tria_Utf8ToAnsi('Обозначение'+';'+'Материал'+';'+'Длина'+';'+'Начало'+';'+'Конец'+#13#10);
  FileWrite(handle,line[1],length(line));
  pv:=cman.beginiterate(ir);
  if pv<>nil then
  begin
                     GDBGetMem({$IFDEF DEBUGBUILD}'{9F4AB2A7-1093-4FFB-8053-E8885D691B85}',{$ENDIF}pointer(pt),sizeof(GDBObjTable));
                     pt^.initnul;
                     zcSetEntPropFromCurrentDrawingProp(pt);
                     pt^.ptablestyle:=drawings.GetCurrentDWG.TableStyleTable.getAddres('KZ');
                     pt^.tbl.free;
  repeat
    begin
         cablename:=pv^.Name;

         if cablename='RS' then
                               cablename:=cablename;

         pstartsegmentvarext:=pv^.StartSegment^.GetExtension(typeof(TVariablesExtender));
         pvd:=pstartsegmentvarext^.entityunit.FindVariable('DB_link');
         CableMaterial:=pstring(pvd^.data.Instance)^;

                                        eq:=DWGDBUnit.FindVariable(CableMaterial);
                                        if eq<>nil then
                                                      begin
                                                           CableMaterial:=PDbBaseObject(eq^.data.Instance)^.NameShort;
                                                      end;
         CableLength:=floattostr(pv^.length);

          firstline:=true;
          devstart:='Не присоединено';
          nodestart:=pv^.Devices.beginiterate(ir_inNodeArray);
          if pv^.StartDevice<>nil then
                                         begin
                                              pvd:=FindVariableInEnt(pv^.StartDevice,'NMO_Name');
                                              if pvd<>nil then
                                                              devstart:=pstring(pvd^.data.Instance)^;
                                              nodeend:=pv^.Devices.iterate(ir_inNodeArray);
                                         end
                                  else
                                      nodeend:=nodestart;
          puredevstart:=devstart;
                {$ifndef GenericsContainerNotFinished}psl:=pointer(pt^.tbl.CreateObject);{$endif}
                psl.init(12);
          repeat
                devend:='Не присоединено';
                repeat
                            if nodeend=nil then system.break;
                            pvd:=FindVariableInEnt(nodeend,'NMO_Name');
                            if pvd=nil then
                                           nodeend:=pv^.Devices.iterate(ir_inNodeArray);
                until pvd<>nil;
                if nodeend<>nil then
                                    devend:=pstring(pvd^.data.Instance)^;
                {psl:=pointer(pt^.tbl.CreateObject);
                psl.init(12);}
                if firstline then
                                 begin
                                 line:='`'+cablename+';'+CableMaterial+';'+CableLength+';'+devstart+';'+devend+#13#10;
                                 s:='';
                                 psl.addutoa((cablename));
                                 psl.addutoa(devstart);
                                 {psl.add(@devend);
                                 psl.add(@s);
                                 psl.add(@s);
                                 psl.add(@s);
                                 psl.add(@s);
                                 psl.add(@CableMaterial);
                                 psl.add(@CableLength);}
                                 end
                             else
                                 begin
                                 line:={cablename+}';'+{CableMaterial+}';'+{CableLength+}';'+devstart+';'+devend+#13#10;
                                 {s:='';
                                 psl.add(@s);
                                 psl.add(@devstart);
                                 psl.add(@devend);
                                 psl.add(@s);
                                 psl.add(@s);
                                 psl.add(@s);
                                 psl.add(@s);
                                 psl.add(@s);
                                 psl.add(@s);}
                                 end;
                line:=Tria_Utf8ToAnsi(line);
                FileWrite(handle,line[1],length(line));
                firstline:=false;
                devstart:=devend;
                nodeend:=pv^.Devices.iterate(ir_inNodeArray);
          until nodeend=nil;
                                 s:='';
                                 psl.addutoa(devend);
                                 psl.addutoa(s);
                                 psl.addutoa(s);
                                 psl.addutoa(s);
                                 psl.addutoa(s);
                                 psl.addutoa(CableMaterial);
                                 psl.addutoa(CableLength);
                                 psl.addutoa(s);
                                 psl.addutoa(s);
                                 s:='';
                                 psl.addutoa(s);

         //ZCMsgCallBackInterface.TextMessage(cablename+' '+CableMaterial+' '+CableLength);
         ZCMsgCallBackInterface.TextMessage('Кабель "'+pv^.Name+'", сегментов '+inttostr(pv^.Segments.Count)+', материал "'+CableMaterial+'", начало: '+puredevstart+' конец: '+devend,TMWOHistoryOut);


    end;
  pv:=cman.iterate(ir);
  until pv=nil;

  drawings.GetCurrentROOT.AddObjectToObjArray{ObjArray.add}(@pt);
  pt^.Build(drawings.GetCurrentDWG^);
  dc:=drawings.GetCurrentDWG^.CreateDrawingRC;
  pt^.FormatEntity(drawings.GetCurrentDWG^,dc);
  end;
  zcRedrawCurrentDrawing;
  FileClose(handle);
  cman.done;
  DefaultFormatSettings.DecimalSeparator := '.';
  end;
  result:=cmd_ok;
end;
function _Material_com_Legend(operands:TCommandOperands):TCommandResult;
var //i: GDBInteger;
    pv:pGDBObjEntity;
    ir,{irincable,ir_inNodeArray,}ir_inscf:itrec;
    s,filename{,cablename,CableMaterial,CableLength,devstart}: GDBString;
    currentgroup:PGDBString;
    handle:cardinal;
    pvad,pvai,pvm:pvardesk;
    //nodeend,nodestart:PTNodeProp;

    line:gdbstring;
    //firstline:boolean;

    bom:GDBBbillOfMaterial;
    PBOMITEM:PGDBBOMItem;

    pt:PGDBObjTable;
    psl{,psfirstline}:PTZctnrVectorGDBString;

    pdbu:ptunit;
    pdbv:pvardesk;
    pdbi:PDbBaseObject;

    cman:TCableManager;
    pcd:PTCableDesctiptor;
    DC:TDrawContext;
    pcablevarext,pstartsegmentvarext:PTVariablesExtender;
begin
  filename:='';
  if SaveFileDialog(filename,'CSV',CSVFileFilter,'','Сохранить данные...') then
  begin
  bom.init(1000);
  handle:=FileCreate(UTF8ToSys(filename),fmOpenWrite);
  line:=Tria_Utf8ToAnsi('Материал'+';'+'Количество'+';'+'Устройства'+#13#10);
  FileWrite(handle,line[1],length(line));
  pv:=drawings.GetCurrentROOT.ObjArray.beginiterate(ir);
  if pv<>nil then
  repeat
    if pv^.GetObjType<>GDBCableID then
    begin
    pcablevarext:=pv^.GetExtension(typeof(TVariablesExtender));
    if pcablevarext<>nil then
    begin
         pvm:=pcablevarext^.entityunit.FindVariable('DB_link');
         if pvm<>nil then
         begin
              pvad:=pcablevarext^.entityunit.FindVariable('AmountD');
              pvai:=pcablevarext^.entityunit.FindVariable('AmountI');
              //if (pvad<>nil)or(pvai<>nil) then
              begin
                   pbomitem:=bom.findorcreate(pstring(pvm^.data.Instance)^);
                   if pbomitem<>nil then
                   begin
                        if (pvad<>nil) then
                                           pbomitem.Amount:=pbomitem.Amount+pgdbdouble(pvad^.data.Instance)^
                   else if (pvai<>nil) then
                                           pbomitem.Amount:=pbomitem.Amount+pgdbinteger(pvai^.data.Instance)^
                   else
                       pbomitem.Amount:=pbomitem.Amount+1;
                        pvm:=pcablevarext^.entityunit.FindVariable('NMO_Name');
                        if (pvm<>nil) then
                                           if pbomitem.Names<>'' then
                                                                     pbomitem.Names:=pbomitem.Names+','+pstring(pvm^.data.Instance)^
                                                                 else
                                                                     pbomitem.Names:=pstring(pvm^.data.Instance)^;


                   end;
              end;
         end;
    end;
    end;
  pv:=drawings.GetCurrentROOT.ObjArray.iterate(ir);
  until pv=nil;

  cman.init;
  cman.build;

  pcd:=cman.beginiterate(ir);
  if pcd<>nil then
  repeat


  if pcd.StartSegment<>nil then
  begin
  pstartsegmentvarext:=pcd.StartSegment^.GetExtension(typeof(TVariablesExtender));
  pvm:=pstartsegmentvarext^.entityunit.FindVariable('DB_link');
  if pvm<>nil then
  begin
       begin
            pbomitem:=bom.findorcreate(pstring(pvm^.data.Instance)^);
            if pbomitem<>nil then
            begin
                 pbomitem.Amount:=pbomitem.Amount+pcd.length;
            end;
       end;
  end;
  end;


  pcd:=cman.iterate(ir);
  until pcd=nil;

  cman.done;

  DefaultFormatSettings.DecimalSeparator := ',';
  PBOMITEM:=bom.beginiterate(ir);
  if PBOMITEM<>nil then
  repeat
          line:=pbomitem.Material+';'+floattostr(pbomitem.Amount)+';'+pbomitem.Names+#13#10;
          line:=Tria_Utf8ToAnsi(line);
          FileWrite(handle,line[1],length(line));

        PBOMITEM:=bom.iterate(ir);
  until PBOMITEM=nil ;
  DefaultFormatSettings.DecimalSeparator := '.';
  FileClose(handle);


                     GDBGetMem({$IFDEF DEBUGBUILD}'{76882CEC-39E7-459C-9CCB-F596DE17539A}',{$ENDIF}pointer(pt),sizeof(GDBObjTable));
                     pt^.initnul;
                     zcSetEntPropFromCurrentDrawingProp(pt);
                     pt^.ptablestyle:=drawings.GetCurrentDWG.TableStyleTable.getAddres('Spec');
                     pt^.tbl.free;

  pdbu:=PTZCADDrawing(drawings.GetCurrentDWG).DWGUnits.findunit(SupportPath,InterfaceTranslate,DrawingDeviceBaseUnitName);
  currentgroup:=MainSpecContentFormat.beginiterate(ir_inscf);
  if currentgroup<>nil then
  if length(currentgroup^)>1 then
  repeat
  if currentgroup^[1]='!' then
              begin
                   {$ifndef GenericsContainerNotFinished}psl:=pointer(pt^.tbl.CreateObject);{$endif}
                   //psl:=pointer(pt^.tbl.CreateObject);
                   psl.init(2);

                   s:='';
                   psl.PushBackData(s);

                   s:=Tria_Utf8ToAnsi(currentgroup^);
                   s:='  '+system.copy(s,2,length(s)-1);
                   //s:='  '+system.copy(currentgroup^,2,length(currentgroup^)-1);
                   psl.PushBackData(s);
            end

  else
      begin
        PBOMITEM:=bom.beginiterate(ir);
        if PBOMITEM<>nil then
        repeat
              pdbv:=pdbu^.FindVariable(PBOMITEM^.Material);
              if pdbv<>nil then
              if not(PBOMITEM.processed) then

              begin
                   pdbi:=pdbv^.data.Instance;
                   if MatchesMask(pdbi^.Group,currentgroup^) then

                   begin
                   PBOMITEM.processed:=true;
                   {$ifndef GenericsContainerNotFinished}psl:=pointer(pt^.tbl.CreateObject);{$endif}
                   //psl:=pointer(pt^.tbl.CreateObject);
                   psl.init(9);

                   s:=pdbi^.Position;
                   psl.addutoa(s);

                   s:=' '+pdbi^.NameFull;
                   psl.addutoa(s);

                   s:=pdbi^.NameShort+' '+pdbi^.Standard;
                   psl.addutoa(s);

                   s:=pdbi^.OKP;
                   psl.addutoa(s);

                   s:=pdbi^.Manufacturer;
                   psl.addutoa(s);

                   s:='??';
                   case pdbi^.EdIzm of
                                      _sht:s:='шт.';
                                      _m:s:='м';
                   end;
                   psl.addutoa(s);

                   s:=floattostr(PBOMITEM^.Amount);
                   psl.PushBackData(s);

                   s:='';
                   psl.addutoa(s);
                   psl.addutoa(s);
                   end;


              end;
                line:=pbomitem.Material+';'+floattostr(pbomitem.Amount)+';'+pbomitem.Names+#13#10;
                FileWrite(handle,line[1],length(line));

              PBOMITEM:=bom.iterate(ir);
        until PBOMITEM=nil;
      end;

        currentgroup:=MainSpecContentFormat.iterate(ir_inscf);
  until currentgroup=nil;

  drawings.GetCurrentROOT.AddObjectToObjArray{ObjArray.add}(@pt);
  pt^.Build(drawings.GetCurrentDWG^);
  dc:=drawings.GetCurrentDWG^.CreateDrawingRC;
  pt^.FormatEntity(drawings.GetCurrentDWG^,dc);


  zcRedrawCurrentDrawing;
  bom.done;
  end;
  result:=cmd_ok;
end;
function _Cable_com_Select(operands:TCommandOperands):TCommandResult;
var //i: GDBInteger;
    pv:pGDBObjEntity;
    ir,irnpa:itrec;
    ptn{,ptnfirst,ptnfirst2,ptnlast,ptnlast2}:PTNodeProp;
    currentobj{,CurrentSubObj,CurrentSubObj2,ptd}:PGDBObjDevice;
begin
  pv:=drawings.GetCurrentROOT.ObjArray.beginiterate(ir);
  if pv<>nil then
  repeat
    if pv^.Selected then
    if pv^.GetObjType=GDBCableID then
    begin
             ptn:=PGDBObjCable(pv)^.NodePropArray.beginiterate(irnpa);
             if ptn<>nil then
                repeat
                    if ptn^.DevLink<>nil then
                    begin
                    CurrentObj:=pointer(ptn^.DevLink^.bp.ListPos.owner);
                    if CurrentObj<>nil then
                                           CurrentObj^.select(drawings.GetCurrentDWG.wa.param.SelDesc.Selectedobjcount,drawings.CurrentDWG^.selector);
                    end;

                    ptn:=PGDBObjCable(pv)^.NodePropArray.iterate(irnpa);
                until ptn=nil;
    end;
  pv:=drawings.GetCurrentROOT.ObjArray.iterate(ir);
  until pv=nil;
  zcRedrawCurrentDrawing;
  result:=cmd_ok;
end;
{
function _Ren_n_to_0n_com(Operands:pansichar):GDBInteger;
var len: GDBInteger;
    pv:pGDBObjEntity;
    ir:itrec;
    pvd:pvardesk;
    name:gdbstring;
begin
  pv:=drawings.GetCurrentROOT.ObjArray.beginiterate(ir);
  if pv<>nil then
  repeat
    if pv^.GetObjType=GDBCableID then
    begin
         pvd:=pv^.ou.FindVariable('NMO_Name');
         if pvd<>nil then
                         begin
                              name:=pgdbstring(pvd.data.Instance)^;
                              len:=length(name);
                              if len=3 then
                              if name[len] in ['0'..'9'] then
                              if not(name[len-1] in ['0'..'9']) then
                              begin
                                   name:=system.copy(name,1,len-1)+'0'+system.copy(name,len,1);
                                   pgdbstring(pvd.data.Instance)^:=name;
                                   ZCMsgCallBackInterface.TextMessage('Переименован кабель '+name);
                              end
                         end;
    end;
  pv:=drawings.GetCurrentROOT.ObjArray.iterate(ir);
  until pv=nil;
end;
}
function VarReport_com(operands:TCommandOperands):TCommandResult;
var pv:pGDBObjEntity;
    ir:itrec;
    pvd:pvardesk;
    name,content:gdbstring;
    VarContents:TZctnrVectorGDBString;
    ps{,pspred}:pgdbstring;
    pentvarext:PTVariablesExtender;
begin
  if operands<>''then
  begin
  VarContents.init(100);
  name:=Operands;
  pv:=drawings.GetCurrentROOT.ObjArray.beginiterate(ir);
  if pv<>nil then
  repeat
    if pv^.Selected then
    begin
    pentvarext:=pv^.GetExtension(typeof(TVariablesExtender));
    pvd:=pentvarext^.entityunit.FindVariable(name);
    if pvd<>nil then
    begin
         content:=pvd.data.PTD.GetValueAsString(pvd.data.Instance);
    end
       else
           begin
                content:='Переменной в описании примитива не обнаружено';
           end;
    VarContents.PushBackData(content);
    end;
  pv:=drawings.GetCurrentROOT.ObjArray.iterate(ir);
  until pv=nil;
  VarContents.sort;

  ps:=VarContents.beginiterate(ir);
  if (ps<>nil) then
  repeat
       ZCMsgCallBackInterface.TextMessage(ps^,TMWOHistoryOut);
       ps:=VarContents.iterate(ir);
  until ps=nil;

  VarContents.Done;
  end
  else
      ZCMsgCallBackInterface.TextMessage('Имя переменной должно быть задано в параметре команды',TMWOHistoryOut);
  zcRedrawCurrentDrawing;
  result:=cmd_ok;
end;

function _Cable_com_Invert(operands:TCommandOperands):TCommandResult;
var //i: GDBInteger;
    pv:pGDBObjEntity;
    ir:itrec;
    DC:TDrawContext;
begin
  dc:=drawings.GetCurrentDWG^.CreateDrawingRC;
  pv:=drawings.GetCurrentROOT.ObjArray.beginiterate(ir);
  if pv<>nil then
  repeat
    if pv^.Selected then
    if pv^.GetObjType=GDBCableID then
    begin
         PGDBObjCable(pv)^.VertexArrayInOCS.invert;
         pv^.Formatentity(drawings.GetCurrentDWG^,dc);
         ZCMsgCallBackInterface.TextMessage('Направление изменено',TMWOHistoryOut);
    end;
  pv:=drawings.GetCurrentROOT.ObjArray.iterate(ir);
  until pv=nil;
  zcRedrawCurrentDrawing;
  result:=cmd_ok;
end;
function _Cable_com_Join(operands:TCommandOperands):TCommandResult;
var //i: GDBInteger;
    pv:pGDBObjEntity;
    pc1,pc2:PGDBObjCable;
    pv11,pv12,pv21,pv22:Pgdbvertex;
    ir:itrec;
    DC:TDrawContext;
begin
  pc1:=nil;
  pc2:=nil;
  pv:=drawings.GetCurrentROOT.ObjArray.beginiterate(ir);
  if pv<>nil then
  repeat
    if pv^.Selected then
    if pv^.GetObjType=GDBCableID then
    begin
         if pc1=nil then
                        pc1:=pointer(pv)
    else if pc2=nil then
                        pc2:=pointer(pv)
    else begin
              ZCMsgCallBackInterface.TextMessage('Выбрано больше 2х кабелей!',TMWOHistoryOut);
              exit;
         end;
    end;
  pv:=drawings.GetCurrentROOT.ObjArray.iterate(ir);
  until pv=nil;
  if pc2=nil then
                 begin
                      ZCMsgCallBackInterface.TextMessage('Выбери 2 кабеля!',TMWOHistoryOut);
                      exit;
                 end;
  pv11:=pc1.VertexArrayInWCS.getDataMutable(0);
  pv12:=pc1.VertexArrayInWCS.getDataMutable(pc1.VertexArrayInWCS.Count-1);
  pv21:=pc2.VertexArrayInWCS.getDataMutable(0);
  pv22:=pc2.VertexArrayInWCS.getDataMutable(pc2.VertexArrayInWCS.Count-1);

     if uzegeometry.Vertexlength(pv11^,pv21^)<eps then
                                                   begin
                                                        pc1.VertexArrayInOCS.Invert;
                                                        pc2.VertexArrayInOCS.deleteelement(0);
                                                        pc2.VertexArrayInOCS.copyto(pc1.VertexArrayInOCS);
                                                        pc2.YouDeleted(drawings.GetCurrentDWG^);
                                                   end
else if uzegeometry.Vertexlength(pv12^,pv21^)<eps then
                                                   begin
                                                        pc2.VertexArrayInOCS.deleteelement(0);
                                                        pc2.VertexArrayInOCS.copyto(pc1.VertexArrayInOCS);
                                                        pc2.YouDeleted(drawings.GetCurrentDWG^);
                                                   end
else if uzegeometry.Vertexlength(pv11^,pv22^)<eps then
                                                   begin
                                                        pc1.VertexArrayInOCS.deleteelement(0);
                                                        pc1.VertexArrayInOCS.copyto(pc2.VertexArrayInOCS);
                                                        pc1.YouDeleted(drawings.GetCurrentDWG^);
                                                        pc1:=pc2
                                                   end
else if uzegeometry.Vertexlength(pv12^,pv22^)<eps then
                                                   begin
                                                        pc2.VertexArrayInOCS.Invert;
                                                        pc2.VertexArrayInOCS.deleteelement(0);
                                                        pc2.VertexArrayInOCS.copyto(pc1.VertexArrayInOCS);
                                                        pc2.YouDeleted(drawings.GetCurrentDWG^);
                                                   end
else
                                                   begin
                                                        ZCMsgCallBackInterface.TextMessage('Кабели не соединены!',TMWOHistoryOut);
                                                        exit;
                                                   end;



  dc:=drawings.GetCurrentDWG^.CreateDrawingRC;
  pc1.formatentity(drawings.GetCurrentDWG^,dc);
  drawings.GetCurrentDWG.wa.param.seldesc.Selectedobjcount:=0;
  drawings.GetCurrentDWG.wa.param.seldesc.OnMouseObject:=nil;
  drawings.GetCurrentDWG.wa.param.seldesc.LastSelectedObject:=nil;
  ZCMsgCallBackInterface.Do_GUIaction(nil,ZMsgID_GUIReturnToDefaultObject);
  clearcp;

  //redrawoglwnd;
  result:=cmd_ok;
end;
function Find_com(operands:TCommandOperands):TCommandResult;
//var i: GDBInteger;
   // pv:pGDBObjEntity;
   // ir:itrec;
begin
  zcShowCommandParams(SysUnit.TypeName2PTD('CommandRTEdObject'),pfindcom);
  drawings.GetCurrentDWG.SelObjArray.Free;
  drawings.GetCurrentROOT.ObjArray.DeSelect(drawings.GetCurrentDWG.wa.param.SelDesc.Selectedobjcount,drawings.GetCurrentDWG^.deselector);
  result:=cmd_ok;
  zcRedrawCurrentDrawing;
end;
procedure commformat;
var pv,pvlast:pGDBObjEntity;
    v:pvardesk;
    varvalue,sourcestr,varname:gdbstring;
    ir:itrec;
    count:integer;
    //a:HandledMsg;
    tpz{, glx1, gly1}: GDBDouble;
  {fv1,}{tp,}wcsLBN,wcsRTF,dcsLBN,dcsRTF: GDBVertex;
    findvarvalue:gdbboolean;
    DC:TDrawContext;
    pentvarext:PTVariablesExtender;
begin
  drawings.GetCurrentDWG.SelObjArray.Free;
  drawings.GetCurrentROOT.ObjArray.DeSelect(drawings.GetCurrentDWG.wa.param.SelDesc.Selectedobjcount,drawings.GetCurrentDWG^.deselector);
   case FindDeviceParam.FindType of
      tft_obozn:begin
                     varname:=('NMO_Name');
                end;
      TFT_DBLink:begin
                     varname:=('DB_link');
                end;
      TFT_DESC_MountingDrawing:begin
                     varname:=('DESC_MountingDrawing');
                end;
   end;

  sourcestr:=uppercase(FindDeviceParam.FindString);

  pv:=drawings.GetCurrentROOT.ObjArray.beginiterate(ir);
  count:=0;
  if pv<>nil then
  repeat
        pentvarext:=pv^.GetExtension(typeof(TVariablesExtender));
        if pentvarext<>nil then
        begin
        findvarvalue:=false;
        v:=pentvarext^.entityunit.FindVariable(varname);
        if v<>nil then
        begin
             varvalue:=uppercase(v^.data.PTD.GetValueAsString(v^.data.Instance));
             findvarvalue:=true;
        end;

        if findvarvalue then
        begin

              case FindDeviceParam.FindMethod of
                   true:begin
                              if MatchesMask(varvalue,sourcestr) then
                                                                     findvarvalue:=true
                                                                 else
                                                                     findvarvalue:=false;
                        end;
                   false:
                         begin
                              if sourcestr=varvalue then
                                                        findvarvalue:=true
                                                    else
                                                        findvarvalue:=false;
                         end;
               end;

               if findvarvalue then
               begin
                  pv^.select(drawings.GetCurrentDWG.wa.param.SelDesc.Selectedobjcount,drawings.CurrentDWG^.selector);
                  pvlast:=pv;
                  inc(count);
               end;
        end;
        end;

  pv:=drawings.GetCurrentROOT.ObjArray.iterate(ir);
  until pv=nil;



  if count=1 then
  begin
        dcsLBN:=InfinityVertex;
        dcsRTF:=MinusInfinityVertex;
        wcsLBN:=InfinityVertex;
        wcsRTF:=MinusInfinityVertex;
        {tp:=}drawings.getcurrentdwg.wa.ProjectPoint(pvlast^.vp.BoundingBox.LBN.x,pvlast^.vp.BoundingBox.LBN.y,pvlast^.vp.BoundingBox.LBN.Z,wcsLBN,wcsRTF,dcsLBN,dcsRTF);
        {tp:=}drawings.getcurrentdwg.wa.ProjectPoint(pvlast^.vp.BoundingBox.RTF.x,pvlast^.vp.BoundingBox.LBN.y,pvlast^.vp.BoundingBox.LBN.Z,wcsLBN,wcsRTF,dcsLBN,dcsRTF);
        {tp:=}drawings.getcurrentdwg.wa.ProjectPoint(pvlast^.vp.BoundingBox.RTF.x,pvlast^.vp.BoundingBox.RTF.y,pvlast^.vp.BoundingBox.LBN.Z,wcsLBN,wcsRTF,dcsLBN,dcsRTF);
        {tp:=}drawings.getcurrentdwg.wa.ProjectPoint(pvlast^.vp.BoundingBox.LBN.x,pvlast^.vp.BoundingBox.RTF.y,pvlast^.vp.BoundingBox.LBN.Z,wcsLBN,wcsRTF,dcsLBN,dcsRTF);
        {tp:=}drawings.getcurrentdwg.wa.ProjectPoint(pvlast^.vp.BoundingBox.LBN.x,pvlast^.vp.BoundingBox.LBN.y,pvlast^.vp.BoundingBox.RTF.Z,wcsLBN,wcsRTF,dcsLBN,dcsRTF);
        {tp:=}drawings.getcurrentdwg.wa.ProjectPoint(pvlast^.vp.BoundingBox.RTF.x,pvlast^.vp.BoundingBox.LBN.y,pvlast^.vp.BoundingBox.RTF.Z,wcsLBN,wcsRTF,dcsLBN,dcsRTF);
        {tp:=}drawings.getcurrentdwg.wa.ProjectPoint(pvlast^.vp.BoundingBox.RTF.x,pvlast^.vp.BoundingBox.RTF.y,pvlast^.vp.BoundingBox.RTF.Z,wcsLBN,wcsRTF,dcsLBN,dcsRTF);
        {tp:=}drawings.getcurrentdwg.wa.ProjectPoint(pvlast^.vp.BoundingBox.LBN.x,pvlast^.vp.BoundingBox.RTF.y,pvlast^.vp.BoundingBox.RTF.Z,wcsLBN,wcsRTF,dcsLBN,dcsRTF);
  drawings.GetCurrentDWG.pcamera^.prop.point.x:=-(wcsLBN.x+(wcsRTF.x-wcsLBN.x)/2);
  drawings.GetCurrentDWG.pcamera^.prop.point.y:=-(wcsLBN.y+(wcsRTF.y-wcsLBN.y)/2);


  drawings.GetCurrentDWG.pcamera^.prop.zoom:=(wcsRTF.x-wcsLBN.x)/drawings.GetCurrentDWG.wa.getviewcontrol.clientwidth;
  tpz:=(wcsRTF.y-wcsLBN.y)/drawings.GetCurrentDWG.wa.getviewcontrol.clientheight;

  if tpz>drawings.GetCurrentDWG.pcamera^.prop.zoom then drawings.GetCurrentDWG.pcamera^.prop.zoom:=tpz;

  drawings.GetCurrentDWG.wa.CalcOptimalMatrix;
  drawings.GetCurrentDWG.wa.mouseunproject(drawings.GetCurrentDWG.wa.param.md.mouse.x, drawings.GetCurrentDWG.wa.param.md.mouse.y);
  drawings.GetCurrentDWG.wa.reprojectaxis;
  //OGLwindow1.param.firstdraw := true;
  //drawings.GetCurrentDWG.pcamera^.getfrustum(@drawings.GetCurrentDWG.pcamera^.modelMatrix,@drawings.GetCurrentDWG.pcamera^.projMatrix,drawings.GetCurrentDWG.pcamera^.clipLCS,drawings.GetCurrentDWG.pcamera^.frustum);
  dc:=drawings.GetCurrentDWG^.CreateDrawingRC;
  drawings.GetCurrentROOT.FormatEntity(drawings.GetCurrentDWG^,dc);
  //drawings.GetCurrentDWG.ObjRoot.calcvisible;
  //drawings.GetCurrentDWG.ConstructObjRoot.calcvisible;
  end;
  zcRedrawCurrentDrawing;
  ZCMsgCallBackInterface.TextMessage('Найдено '+inttostr(count)+' объектов',TMWOHistoryOut);
end;
function _Cable_mark_com(operands:TCommandOperands):TCommandResult;
var //i: GDBInteger;
    pv:pGDBObjDevice;
    ir{,irincable,ir_inNodeArray}:itrec;
    //filename,cablename,CableMaterial,CableLength,devstart,devend: GDBString;
    //handle:cardinal;
    pvn{,pvm,pvmc,pvl}:pvardesk;
    //nodeend,nodestart:PTNodeProp;

    //line:gdbstring;
    cman:TCableManager;
    pcd:PTCableDesctiptor;
    DC:TDrawContext;
    pentvarext:PTVariablesExtender;
begin
  cman.init;
  cman.build;
  dc:=drawings.GetCurrentDWG^.CreateDrawingRC;
  pv:=drawings.GetCurrentROOT.ObjArray.beginiterate(ir);
  if pv<>nil then
  repeat
    begin
         if pv^.GetObjType=GDBDeviceID then
         if pv^.Name='CABLE_MARK' then
         begin
              pentvarext:=pv^.GetExtension(typeof(TVariablesExtender));
              pvn:=pentvarext^.entityunit.FindVariable('CableName');
              if (pvn<>nil) then
              begin
                   pcd:=cman.Find(pstring(pvn^.data.Instance)^);
                   if pcd<>nil then
                   begin
                        Cable2CableMark(pcd,pv);
                        {pvm:=pv^.ou.FindVariable('CableMaterial');
                        if pvm<>nil then
                                    begin
                                        pvmc:=pcd^.StartSegment^.FindVariable('DB_link');
                                        if pvmc<>nil then
                                        begin
                                        line:=pstring(pvmc^.data.Instance)^;
                                        pstring(pvm^.data.Instance)^:=line;
                                        end
                                        else
                                            pgdbstring(pvm^.data.Instance)^:='Не определен';
                                    end;
                       pvl:=pv^.ou.FindVariable('CableLength');
                       if pvl<>nil then
                                       pgdbdouble(pvl^.data.Instance)^:=pcd^.length;}
                       pv^.Formatentity(drawings.GetCurrentDWG^,dc);
                   end
                      else
                          ZCMsgCallBackInterface.TextMessage('Кабель "'+pstring(pvn^.data.Instance)^+'" на плане не найден',TMWOHistoryOut);
              end;
         end;
    end;
  pv:=drawings.GetCurrentROOT.ObjArray.iterate(ir);
  until pv=nil;

  zcRedrawCurrentDrawing;
  cman.done;
  result:=cmd_ok;
end;
function El_Leader_com_AfterClick(wc: GDBvertex; mc: GDBvertex2DI; var button: GDBByte;osp:pos_record;mclick:GDBInteger): GDBInteger;
var //po:PGDBObjSubordinated;
    pleader:PGDBObjElLeader;
    domethod,undomethod:tmethod;
    DC:TDrawContext;
begin
  //result:=Line_com_AfterClick(wc,mc,button,osp,mclick);
  result:=mclick;
  PCreatedGDBLine^.vp.Layer :=drawings.GetCurrentDWG.GetCurrentLayer;
  PCreatedGDBLine^.vp.lineweight := sysvar.dwg.DWG_CLinew^;
  PCreatedGDBLine^.CoordInOCS.lEnd:= wc;
  dc:=drawings.GetCurrentDWG^.CreateDrawingRC;
  PCreatedGDBLine^.Formatentity(drawings.GetCurrentDWG^,dc);
  //po:=nil;
  if osp<>nil then
  begin
       if (PGDBObjEntity(osp^.PGDBObject)<>nil)and(osp^.PGDBObject<>pold)
       then
       begin
            PGDBObjEntity(osp^.PGDBObject)^.formatentity(drawings.GetCurrentDWG^,dc);
            //PGDBObjEntity(osp^.PGDBObject)^.ObjToGDBString('Found: ','');
            ZCMsgCallBackInterface.TextMessage(PGDBObjline(osp^.PGDBObject)^.ObjToGDBString('Found: ',''),TMWOHistoryOut);
            //po:=PGDBObjEntity(osp^.PGDBObject)^.getowner;
            pold:=osp^.PGDBObject;
       end
  end else pold:=nil;
  //pl^.RenderFeedback;
  if (button and MZW_LBUTTON)<>0 then
  begin
    begin
    PCreatedGDBLine^.bp.ListPos.Owner:=drawings.GetCurrentROOT;

  GDBGetMem({$IFDEF DEBUGBUILD}'{33202D9B-6197-4A09-8BC8-1D24AA3053DA}',{$ENDIF}pointer(pleader),sizeof(GDBObjElLeader));
  pleader^.initnul;
  //pleader^.ou.copyfrom(units.findunit('_riser'));
  pleader^.scale:=ELLeaderComParam.Scale;
  pleader^.size:=ELLeaderComParam.Size;
  pleader^.twidth:=ELLeaderComParam.twidth;
  zcSetEntPropFromCurrentDrawingProp(pleader);
  drawings.standardization(pleader,GDBELleaderID);
  pleader.MainLine.CoordInOCS.lBegin:=PCreatedGDBLine^.CoordInOCS.lBegin;
  pleader.MainLine.CoordInOCS.lEnd:=PCreatedGDBLine^.CoordInOCS.lEnd;


  SetObjCreateManipulator(domethod,undomethod);
  with PushMultiObjectCreateCommand(PTZCADDrawing(drawings.GetCurrentDWG).UndoStack,tmethod(domethod),tmethod(undomethod),1)^ do
  begin
       AddObject(pleader);
       comit;
  end;

  //drawings.GetCurrentROOT.AddObjectToObjArray{ObjArray.add}(@pleader);
  pleader^.Formatentity(drawings.GetCurrentDWG^,dc);
  //pleader.BuildGeometry;

    end;
    drawings.GetCurrentDWG.ConstructObjRoot.ObjArray.free;
    result:=-1;
    zcRedrawCurrentDrawing;
  end;
end;
function ElLeaser_com_CommandStart(operands:TCommandOperands):TCommandResult;
begin
  pold:=nil;
  drawings.GetCurrentDWG.wa.SetMouseMode((MGet3DPoint) or (MMoveCamera) or (MRotateCamera));
  sysvarDWGOSMode:=sysvarDWGOSMode or osm_nearest;
  zcShowCommandParams(SysUnit.TypeName2PTD('TELLeaderComParam'),@ELLeaderComParam);
  ZCMsgCallBackInterface.TextMessage('Первая точка:',TMWOHistoryOut);
  result:=cmd_ok;
end;
function _Cable_com_Manager(operands:TCommandOperands):TCommandResult;
//var i: GDBInteger;
    //pv:pGDBObjEntity;
    //ir:itrec;
begin
        CableManager.init;
        CableManager.build;
        zcShowCommandParams(SysUnit.TypeName2PTD('TCableManager'),@CableManager);
        result:=cmd_ok;
end;
function _Ren_n_to_0n_com(operands:TCommandOperands):TCommandResult;
var {i,}len: GDBInteger;
    pv:pGDBObjEntity;
    ir:itrec;
    pvd{,pvn,pvm,pvmc,pvl}:pvardesk;
    name:gdbstring;
    pentvarext:PTVariablesExtender;
begin
  pv:=drawings.GetCurrentROOT.ObjArray.beginiterate(ir);
  if pv<>nil then
  repeat
    if pv^.GetObjType=GDBCableID then
    begin
         pentvarext:=pv^.GetExtension(typeof(TVariablesExtender));
         pvd:=pentvarext^.entityunit.FindVariable('NMO_Name');
         if pvd<>nil then
                         begin
                              name:=pgdbstring(pvd.data.Instance)^;
                              len:=length(name);
                              if len=3 then
                              if name[len] in ['0'..'9'] then
                              if not(name[len-1] in ['0'..'9']) then
                              begin
                                   name:=system.copy(name,1,len-1)+'0'+system.copy(name,len,1);
                                   pgdbstring(pvd.data.Instance)^:=name;
                                   ZCMsgCallBackInterface.TextMessage('Переименован кабель '+name,TMWOHistoryOut);
                              end
                                 {else
                                     ZCMsgCallBackInterface.TextMessage(name);;}
                         end;
    end;
  pv:=drawings.GetCurrentROOT.ObjArray.iterate(ir);
  until pv=nil;
  result:=cmd_ok;
end;
function _SelectMaterial_com(operands:TCommandOperands):TCommandResult;
var //i,len: GDBInteger;
    pv:pGDBObjEntity;
    ir:itrec;
    pvd{,pvn,pvm,pvmc,pvl}:pvardesk;
    mat:gdbstring;
    pentvarext:PTVariablesExtender;
begin
  pv:=drawings.GetCurrentROOT.ObjArray.beginiterate(ir);
  if pv<>nil then
  repeat
    if (pv^.GetObjType=GDBCableID)
    or (pv^.GetObjType=GDBCableID) then
    begin
         pentvarext:=pv^.GetExtension(typeof(TVariablesExtender));
         pvd:=pentvarext^.entityunit.FindVariable('DB_link');
         if pvd<>nil then
                         begin
                              mat:=pgdbstring(pvd.data.Instance)^;
                              if uppercase(mat)=uppercase(operands) then
                                                                        begin
                                                                        //pv^.Select;
                                                                        pgdbstring(pvd.data.Instance)^:='ТППэП 20х2х0.5';
                                                                        end;
                         end;
    end;
  pv:=drawings.GetCurrentROOT.ObjArray.iterate(ir);
  until pv=nil;
  result:=cmd_ok;
  //commandmanager.executecommandend;
  //OGLwindow1.SetObjInsp;
      //updatevisible;
end;
function findconnector(CurrentObj:PGDBObjDevice):PGDBObjDevice;
var
    CurrentSubObj:PGDBObjDevice;
    {ir_inGDB,ir_inVertexArray,ir_inNodeArray,}ir_inDevice:itrec;
begin
     result:=nil;
CurrentSubObj:=CurrentObj^.VarObjArray.beginiterate(ir_inDevice);
if (CurrentSubObj<>nil) then
repeat
      if (CurrentSubObj^.GetObjType=GDBDeviceID) then
      begin
      if CurrentSubObj^.BlockDesc.BType=BT_Connector then
                                                         begin
                                                              result:=CurrentSubObj;
                                                              exit;
                                                         end;
      end;
      CurrentSubObj:=CurrentObj^.VarObjArray.iterate(ir_inDevice);
until CurrentSubObj=nil;
end;
function CreateCable(name,mater:gdbstring):PGDBObjCable;
var
    //vd,pvn,pvn2: pvardesk;
    pvd{,pvd2}:pvardesk;
    pentvarext:PTVariablesExtender;
begin
  result := AllocCable;
  result.init(drawings.GetCurrentROOT,nil,0);
  //result := GDBPointer(drawings.GetCurrentROOT.ObjArray.CreateInitObj(GDBCableID,drawings.GetCurrentROOT));
  pentvarext:=result^.GetExtension(typeof(TVariablesExtender));
  pentvarext^.entityunit.copyfrom(units.findunit(SupportPath,InterfaceTranslate,'cable'));
  pvd:=pentvarext^.entityunit.FindVariable('NMO_Suffix');
  pstring(pvd^.data.Instance)^:='';
  pvd:=pentvarext^.entityunit.FindVariable('NMO_Prefix');
  pstring(pvd^.data.Instance)^:='';
  pvd:=pentvarext^.entityunit.FindVariable('NMO_BaseName');
  pstring(pvd^.data.Instance)^:='';
  pvd:=pentvarext^.entityunit.FindVariable('NMO_Template');
  pstring(pvd^.data.Instance)^:='';
  pvd:=pentvarext^.entityunit.FindVariable('NMO_Name');
  pstring(pvd^.data.Instance)^:=name;
  pvd:=pentvarext^.entityunit.FindVariable('DB_link');
  pstring(pvd^.data.Instance)^:=mater;

  pvd:=pentvarext^.entityunit.FindVariable('CABLE_AutoGen');
  pgdbboolean(pvd^.data.Instance)^:=true;
  zcSetEntPropFromCurrentDrawingProp(result);
  drawings.standardization(result,GDBCableID);
end;

function _El_ExternalKZ_com(operands:TCommandOperands):TCommandResult;
var
    FDoc: TCSVDocument;
    isload:boolean;
    s: GDBString;
    row,col:integer;
    startdev,enddev,riser,riser2:PGDBObjDevice;
    supernet,net,net2:PGDBObjNet;
    cable:PGDBObjCable;
    pvd,pvd2:pvardesk;
    netarray,riserarray,linesarray:TZctnrVectorPGDBaseObjects;
    processednets:TZctnrVectorPGDBaseObjects;
    segments:TZctnrVectorPGDBaseObjects;

    ir_net,ir_net2,ir_riser,ir_riser2:itrec;
    nline,new_line:pgdbobjline;
    np:GDBVertex;
    //net2processed:boolean;
    vd,pvn,pvn2: pvardesk;
    supernetsarray:GDBObjOpenArrayOfPV;
    DC:TDrawContext;
    priservarext,priser2varext,psupernetvarext,pnetvarext,plinevarext:PTVariablesExtender;
    lph:TLPSHandle;
procedure GetStartEndPin(startdevname,enddevname:GDBString);
begin
  PGDBObjEntity(startdev):=drawings.FindEntityByVar(GDBDeviceID,'NMO_Name',startdevname);
  PGDBObjEntity(enddev):=drawings.FindEntityByVar(GDBDeviceID,'NMO_Name',enddevname);
  if startdev=nil then
                      ZCMsgCallBackInterface.TextMessage('В строке '+inttostr(row)+' не найдено стартовое устройство '+startdevname,TMWOHistoryOut)
                  else
                      begin
                      startdev:=findconnector(startdev);
                      if startdev=nil then
                                          ZCMsgCallBackInterface.TextMessage('В строке '+inttostr(row)+' не найден коннектор стартового устройства '+startdevname,TMWOHistoryOut);
                      end;
  if enddev=nil then
                      ZCMsgCallBackInterface.TextMessage('В строке '+inttostr(row)+' не найдено конечное устройство '+enddevname,TMWOHistoryOut)
                  else
                      begin
                      enddev:=findconnector(enddev);
                      if enddev=nil then
                                          ZCMsgCallBackInterface.TextMessage('В строке '+inttostr(row)+' не найден коннектор конечного устройства '+enddevname,TMWOHistoryOut);

                      end;
end;
procedure LinkRisersToNets;
begin
  drawings.FindMultiEntityByVar2(GDBDeviceID,'RiserName',riserarray);
  supernet:=nil;
  net:=netarray.beginiterate(ir_net);
  if (net<>nil) then
  repeat
        net.riserarray.Clear;
        riser:=riserarray.beginiterate(ir_riser);
        if (riser<>nil) then
        repeat
              pointer(nline):=net.GetNearestLine(riser.P_insert_in_WCS);
              np:=NearestPointOnSegment(riser.P_insert_in_WCS,nline.CoordInWCS.lBegin,nline.CoordInWCS.lEnd);
              if IsPointEqual(np,riser.P_insert_in_WCS)then
              begin
                   net.riserarray.PushBackData(riser);
              end;
              riser:=riserarray.iterate(ir_riser);
        until riser=nil;
        net:=netarray.iterate(ir_net);
  until net=nil;
end;

begin
  linesarray.init({$IFDEF DEBUGBUILD}'{B2D2F2AE-360B-4755-8DE8-A950788B7533}',{$ENDIF}10);
  dc:=drawings.GetCurrentDWG^.CreateDrawingRC;
  if length(operands)=0 then
                     begin
                          isload:=OpenFileDialog(s,1,'csv',CSVFileFilter,'','Открыть журнал...');
                          if not isload then
                                            begin
                                                 result:=cmd_cancel;
                                                 exit;
                                            end
                                        else
                                            begin

                                            end;

                     end
                 else
                 begin
                                           begin
                                           s:=ExpandPath(operands);
                                           s:=FindInSupportPath(SupportPath,operands);
                                           end;
                 end;
  isload:=FileExists(utf8tosys(s));
  if isload then
  begin
       processednets.init({$IFDEF DEBUGBUILD}'{01A8C9B3-E4A9-4A72-9697-A7049151B7B7}',{$ENDIF}100);
       supernetsarray.init({$IFDEF DEBUGBUILD}'{B8FBA153-889E-4FC7-AF16-5DE56A14A72F}',{$ENDIF}100);
       FDoc:=TCSVDocument.Create;
       FDoc.Delimiter:=';';
       FDoc.LoadFromFile(utf8tosys(s));
       lph:=lps.StartLongProcess(FDoc.RowCount,'Create cables',nil);
       netarray.init({$IFDEF DEBUGBUILD}'{6FC12C96-F62C-47A3-A5B4-35D9564DB25E}',{$ENDIF}100);
       for row:=0 to FDoc.RowCount-1 do
       begin
            if FDoc.ColCount[row]>4 then
            begin
                 //if FDoc.Cells[0,row]='0S1' then
                 //                                 log.LogOut('asdasd');
                 //s:='прочитана строка';
                 //for col:=0 to FDoc.ColCount[row] do
                 //begin
                 //s:=s+' '+FDoc.Cells[col,row];
                 //end;
                 //log.LogOut(s);


            netarray.Clear;
            drawings.FindMultiEntityByVar(GDBNetID,'NMO_Name',FDoc.Cells[3,row],netarray);

                 GetStartEndPin(FDoc.Cells[1,row],FDoc.Cells[2,row]);

                 {PGDBObjEntity(startdev):=drawings.FindEntityByVar(GDBDeviceID,'NMO_Name',FDoc.Cells[1,row]);
                 PGDBObjEntity(enddev):=drawings.FindEntityByVar(GDBDeviceID,'NMO_Name',FDoc.Cells[2,row]);
                 if startdev=nil then
                                     ZCMsgCallBackInterface.TextMessage('В строке '+inttostr(row)+' не найдено стартовое устройство '+FDoc.Cells[1,row])
                                 else
                                     begin
                                     startdev:=findconnector(startdev);
                                     if startdev=nil then
                                                         ZCMsgCallBackInterface.TextMessage('В строке '+inttostr(row)+' не найден коннектор стартового устройства '+FDoc.Cells[1,row]);
                                     end;
                 if enddev=nil then
                                     ZCMsgCallBackInterface.TextMessage('В строке '+inttostr(row)+' не найдено конечное устройство '+FDoc.Cells[2,row])
                                 else
                                     begin
                                     enddev:=findconnector(enddev);
                                     if enddev=nil then
                                                         ZCMsgCallBackInterface.TextMessage('В строке '+inttostr(row)+' не найден коннектор конечного устройства '+FDoc.Cells[2,row]);

                                     end;}
                 if (startdev<>nil)and(enddev<>nil) then
                 if netarray.Count=1 then
                 begin
                  PGDBaseObject(net):=netarray.getDataMutable(0);
                 //PGDBObjEntity(net):=drawings.FindEntityByVar(GDBNetID,'NMO_Name',FDoc.Cells[3,row]);
                 if net=nil then
                                     ZCMsgCallBackInterface.TextMessage('В строке '+inttostr(row)+' не найдена трасса '+FDoc.Cells[3,row],TMWOHistoryOut);
                 if (net<>nil) then
                 begin
                 //startdev:=findconnector(startdev);
                 //enddev:=findconnector(enddev);
                 //if startdev=nil then
                 //                    ZCMsgCallBackInterface.TextMessage('В строке '+inttostr(row)+' не найден коннектор стартового устройства '+FDoc.Cells[1,row]);
                 //if enddev=nil then
                 //                    ZCMsgCallBackInterface.TextMessage('В строке '+inttostr(row)+' не найден коннектор конечного устройства '+FDoc.Cells[2,row]);
                 if (startdev<>nil)and(enddev<>nil) then
                 begin
                 cable:=CreateCable(FDoc.Cells[0,row],FDoc.Cells[4,row]);
                 {
                 cable := GDBPointer(drawings.GetCurrentROOT.ObjArray.CreateinitObj(GDBCableID,drawings.GetCurrentROOT));
                 cable^.ou.copyfrom(units.findunit('cable'));
                 pvd:=cable.ou.FindVariable('NMO_Suffix');
                 pstring(pvd^.data.Instance)^:='';
                 pvd:=cable.ou.FindVariable('NMO_Prefix');
                 pstring(pvd^.data.Instance)^:='';
                 pvd:=cable.ou.FindVariable('NMO_BaseName');
                 pstring(pvd^.data.Instance)^:='';
                 pvd:=cable.ou.FindVariable('NMO_Template');
                 pstring(pvd^.data.Instance)^:='';
                 pvd:=cable.ou.FindVariable('NMO_Name');
                 pstring(pvd^.data.Instance)^:=FDoc.Cells[0,row];
                 pvd:=cable.ou.FindVariable('DB_link');
                 pstring(pvd^.data.Instance)^:=FDoc.Cells[4,row];

                 pvd:=cable.ou.FindVariable('CABLE_AutoGen');
                 pgdbboolean(pvd^.data.Instance)^:=true;}

                 //drawings.GetCurrentROOT.ObjArray.ObjTree.{AddObjectToNodeTree(cable)}CorrectNodeBoundingBox(cable^);

                 rootbytrace(startdev.P_insert_in_WCS,enddev.P_insert_in_WCS,net,Cable,true);
                 zcAddEntToCurrentDrawingWithUndo(Cable);
                 Cable^.Formatentity(drawings.GetCurrentDWG^,dc);
                 Cable^.RenderFeedback(drawings.GetCurrentDWG.pcamera^.POSCOUNT,drawings.GetCurrentDWG.pcamera^,drawings.GetCurrentDWG^.myGluProject2,dc);
                 //drawings.GetCurrentROOT.ObjArray.ObjTree.CorrectNodeBoundingBox(Cable^);
                 end;

                 end;
                 end
                 else
                     begin
                          if netarray.Count>1 then
                          begin
                          supernet:=PGDBObjNet(FindEntityByVar(supernetsarray,GDBNetID,'NMO_Name',FDoc.Cells[3,row]));

                          if supernet=nil then
                          begin
                          riserarray.init({$IFDEF DEBUGBUILD}'{FC1F0E75-3A1C-4144-A901-7DCE7B8BB0BB}',{$ENDIF}100);
                          drawings.FindMultiEntityByVar2(GDBDeviceID,'RiserName',riserarray);

                          LinkRisersToNets;
                          processednets.Clear;
                          net:=netarray.beginiterate(ir_net);
                          if (net<>nil) then
                          repeat
                                pnetvarext:=net^.GetExtension(typeof(TVariablesExtender));
                                //ir_net2:=ir_net;
                                //net2:=netarray.iterate(ir_net2);
                                net2:=netarray.beginiterate(ir_net2);

                                if (net2<>nil) then
                                repeat
                                      if net<>net2 then
                                      begin

                                      //net2processed:=false;
                                      riser:=net.riserarray.beginiterate(ir_riser);
                                      if (riser<>nil) then
                                      repeat
                                            priservarext:=riser^.GetExtension(typeof(TVariablesExtender));
                                            riser2:=net2.riserarray.beginiterate(ir_riser2);
                                            if (riser2<>nil) then
                                            repeat
                                                  if not uzegeometry.vertexeq(riser2.P_insert_in_WCS,riser.P_insert_in_WCS) then
                                                  begin
                                                  priser2varext:=riser2^.GetExtension(typeof(TVariablesExtender));
                                                  //pvd:=PTObjectUnit(riser.ou.Instance)^.FindVariable('RiserName');
                                                  //pvd2:=PTObjectUnit(riser2.ou.Instance)^.FindVariable('RiserName');
                                                  pvd:=priservarext^.entityunit.FindVariable('RiserName');
                                                  pvd2:=priser2varext^.entityunit.FindVariable('RiserName');
                                                  if (pvd<>nil)and(pvd2<>nil) then
                                                  begin
                                                       if pstring(pvd^.data.Instance)^=pstring(pvd2^.data.Instance)^then
                                                       begin
                                                            if supernet=nil then
                                                            begin
                                                                 gdbgetmem({$IFDEF DEBUGBUILD}'{79828350-69E9-418A-A023-BB8B187639A1}',{$ENDIF}supernet,sizeof(GDBObjNet));
                                                                 supernet.initnul(nil);
                                                                 psupernetvarext:=supernet.GetExtension(typeof(TVariablesExtender));

                                                                 //PTObjectUnit(supernet.ou.Instance)^.copyfrom(PTObjectUnit(net.ou.Instance));
                                                                 psupernetvarext^.entityunit.copyfrom(@pnetvarext.entityunit);
                                                                 //log.LogOut('supernet.initnul(nil); Примитивов в графе: '+inttostr(supernet^.objarray.count));
                                                            end;
                                                            if not processednets.IsDataExist(net)<>-1 then
                                                            begin
                                                                 net.objarray.copyto(supernet.ObjArray);
                                                                 processednets.PushBackData(net);
                                                                 //net2processed:=true;
                                                                 //log.LogOut('processednets.AddByRef(net^); Примитивов в графе: '+inttostr(supernet^.objarray.count));
                                                            end;

                                                            if not processednets.IsDataExist(net2)<>-1 then
                                                            begin
                                                                 net2.objarray.copyto(supernet.ObjArray);
                                                                 processednets.PushBackData(net2);
                                                                 //net2processed:=true;
                                                                 //log.LogOut('processednets.AddByRef(net2^); Примитивов в графе: '+inttostr(supernet^.objarray.count));
                                                            end;

                                                                New_line:=PGDBObjLine(ENTF_CreateLine(drawings.GetCurrentROOT,{@drawings.GetCurrentDWG^.ConstructObjRoot.ObjArray}nil,[riser.P_insert_in_WCS.x,riser.P_insert_in_WCS.y,riser.P_insert_in_WCS.z,riser2.P_insert_in_WCS.x,riser2.P_insert_in_WCS.y,riser2.P_insert_in_WCS.z]));
                                                                zcSetEntPropFromCurrentDrawingProp(New_line);
                                                                //New_line := GDBPointer(drawings.GetCurrentDWG.ConstructObjRoot.ObjArray.CreateObj(GDBLineID{,drawings.GetCurrentROOT}));
                                                                //GDBObjLineInit(drawings.GetCurrentROOT,New_line,drawings.GetCurrentDWG.LayerTable.GetCurrentLayer,sysvar.dwg.DWG_CLinew^,riser.P_insert_in_WCS,riser2.P_insert_in_WCS);
                                                                plinevarext:=New_line^.GetExtension(typeof(TVariablesExtender));
                                                                if plinevarext=nil then
                                                                                       plinevarext:=AddVariablesToEntity(New_line);
                                                                plinevarext^.entityunit.copyfrom(units.findunit(SupportPath,InterfaceTranslate,'_riserlink'));
                                                                vd:=plinevarext^.entityunit.FindVariable('LengthOverrider');

                                                                pvn :=FindVariableInEnt(riser,'Elevation');
                                                                pvn2:=FindVariableInEnt(riser,'Elevation');
                                                                if (pvn<>nil)and(pvn2<>nil)and(vd<>nil)then
                                                                begin
                                                                     pgdbdouble(vd^.data.Instance)^:=abs(pgdbdouble(pvn^.data.Instance)^-pgdbdouble(pvn2^.data.Instance)^);
                                                                end;
                                                                New_line^.Formatentity(drawings.GetCurrentDWG^,dc);
                                                                //New_line.bp.ListPos.Owner^.RemoveInArray(New_line.bp.ListPos.SelfIndex);
                                                                supernet^.ObjArray.AddPEntity(New_line^);
                                                                linesarray.PushBackData(New_line);
                                                                //log.LogOut('supernet^.ObjArray.add(addr(New_line)); Примитивов в графе: '+inttostr(supernet^.objarray.count));


                                                            pvd:=pvd;
                                                       end;
                                                  end;
                                                  end;

                                                 riser2:=net2.riserarray.iterate(ir_riser2);
                                            until riser2=nil;


                                           riser:=net.riserarray.iterate(ir_riser);
                                      until riser=nil;

                                end;
                                net2:=netarray.iterate(ir_net2);
                                until net2=nil;

                                net:=netarray.iterate(ir_net);
                          until (net=nil){or(supernet<>nil)};
                          riserarray.Clear;
                          riserarray.Done;
                          if supernet<>nil then
                                          supernetsarray.PushBackData(supernet);
                          end
                             else
                                 supernet:=supernet;

                          //supernet.BuildGraf;

                          if supernet<>nil then
                          begin
                          cable:=CreateCable(FDoc.Cells[0,row],FDoc.Cells[4,row]);
                          {cable := GDBPointer(drawings.GetCurrentROOT.ObjArray.CreateinitObj(GDBCableID,drawings.GetCurrentROOT));
                          cable^.ou.copyfrom(units.findunit('cable'));
                          pvd:=cable.ou.FindVariable('NMO_Suffix');
                          pstring(pvd^.data.Instance)^:='';
                          pvd:=cable.ou.FindVariable('NMO_Prefix');
                          pstring(pvd^.data.Instance)^:='';
                          pvd:=cable.ou.FindVariable('NMO_BaseName');
                          pstring(pvd^.data.Instance)^:='';
                          pvd:=cable.ou.FindVariable('NMO_Template');
                          pstring(pvd^.data.Instance)^:='';
                          pvd:=cable.ou.FindVariable('NMO_Name');
                          pstring(pvd^.data.Instance)^:=FDoc.Cells[0,row];
                          pvd:=cable.ou.FindVariable('DB_link');
                          pstring(pvd^.data.Instance)^:=FDoc.Cells[4,row];

                          pvd:=cable.ou.FindVariable('CABLE_AutoGen');
                          pgdbboolean(pvd^.data.Instance)^:=true;}

                          //drawings.GetCurrentROOT.ObjArray.ObjTree.{AddObjectToNodeTree(cable)}CorrectNodeBoundingBox(cable^);

                          //log.LogOut('Примитивов в графе: '+inttostr(supernet^.objarray.count));

                          segments:=rootbymultitrace(startdev.P_insert_in_WCS,enddev.P_insert_in_WCS,supernet,Cable,true);
                          zcAddEntToCurrentDrawingWithUndo(Cable);
                          zcSetEntPropFromCurrentDrawingProp(Cable);
                          drawings.standardization(Cable,GDBCableID);
                          Cable^.Formatentity(drawings.GetCurrentDWG^,dc);
                          Cable^.RenderFeedback(drawings.GetCurrentDWG.pcamera^.POSCOUNT,drawings.GetCurrentDWG.pcamera^,drawings.GetCurrentDWG^.myGluProject2,dc);
                          //drawings.GetCurrentROOT.ObjArray.ObjTree.CorrectNodeBoundingBox(Cable^);

                          cable:=segments.beginiterate(ir_net);
                          if (cable<>nil) then
                          repeat
                                zcAddEntToCurrentDrawingWithUndo(Cable);
                                zcSetEntPropFromCurrentDrawingProp(Cable);
                                drawings.standardization(Cable,GDBCableID);
                                Cable^.Formatentity(drawings.GetCurrentDWG^,dc);
                                Cable^.RenderFeedback(drawings.GetCurrentDWG.pcamera^.POSCOUNT,drawings.GetCurrentDWG.pcamera^,drawings.GetCurrentDWG^.myGluProject2,dc);
                                //drawings.GetCurrentROOT.ObjArray.ObjTree.CorrectNodeBoundingBox(Cable^);

                          cable:=segments.iterate(ir_net);
                          until cable=nil;

                          //supernet.objarray.Clear;
                          //supernet.riserarray.clear;
                          //supernet.done;
                          segments.Clear;
                          segments.done;
                          //drawings.GetCurrentDWG.ConstructObjRoot.ObjArray.Clear;
                          end
                          else
                              ZCMsgCallBackInterface.TextMessage('В строке '+inttostr(row)+' обнаружено несколько не связанных трасс "'+FDoc.Cells[3,row],TMWOShowError);



                          //TMWOShowError('В строке '+inttostr(row)+' обнаружена множественная трасса "'+FDoc.Cells[3,row]+'". Пока недопилено((');
                          end
                          else
                              ZCMsgCallBackInterface.TextMessage('В строке '+inttostr(row)+' обнаружена трасса "'+FDoc.Cells[3,row]+'" отсутствующая в чертеже((',TMWOShowError);
                     end;


            end
            else
                begin
                ZCMsgCallBackInterface.TextMessage('В строке '+inttostr(row)+'мало параметров',TMWOHistoryOut);
                for col:=0 to FDoc.ColCount[row] do
                ZCMsgCallBackInterface.TextMessage(FDoc.Cells[col,row],TMWOHistoryOut);
                end;
       lps.ProgressLongProcess(lph,row);
       end;
       netarray.Clear;
       netarray.Done;

       FDoc.Destroy;
       processednets.Clear;
       processednets.Done;

       net:=supernetsarray.beginiterate(ir_net);
       if (net<>nil) then
       repeat
            net.objarray.Clear;
            net.riserarray.clear;
            net:=supernetsarray.iterate(ir_net);
       until net=nil;
       supernetsarray.done;
       linesarray.done;


       lps.EndLongProcess(lph)
  end
            else
     ZCMsgCallBackInterface.TextMessage('GDBCommandsElectrical.El_ExternalKZ: Не могу открыть файл: '+s+'('+Operands+')',TMWOShowError);
end;
function _AutoGenCableRemove_com(operands:TCommandOperands):TCommandResult;
var //i,len: GDBInteger;
    pv:pGDBObjEntity;
    ir:itrec;
    pvd{,pvn,pvm,pvmc,pvl}:pvardesk;
    //mat:gdbstring;
begin
  pv:=drawings.GetCurrentROOT.ObjArray.beginiterate(ir);
  if pv<>nil then
  repeat
    if (pv^.GetObjType=GDBCableID) then
    begin
         //pvd:=PTObjectUnit(pv^.ou.Instance)^.FindVariable('CABLE_AutoGen');
         pvd:=FindVariableInEnt(pv,'CABLE_AutoGen');
         if pvd<>nil then
                         begin
                              if pgdbboolean(pvd^.data.Instance)^ then
                                                                        begin
                                                                        pv^.YouDeleted(drawings.GetCurrentDWG^);
                                                                        end;
                         end;
    end;
  pv:=drawings.GetCurrentROOT.ObjArray.iterate(ir);
  until pv=nil;
  drawings.GetCurrentDWG.wa.param.seldesc.Selectedobjcount:=0;
  drawings.GetCurrentDWG.wa.param.seldesc.OnMouseObject:=nil;
  drawings.GetCurrentDWG.wa.param.seldesc.LastSelectedObject:=nil;
  drawings.GetCurrentDWG.wa.param.lastonmouseobject:=nil;
  drawings.GetCurrentDWG.SelObjArray.Clear;
  ZCMsgCallBackInterface.Do_GUIaction(nil,ZMsgID_GUIReturnToDefaultObject);
  clearcp;
  result:=cmd_ok;
end;

function _test_com(operands:TCommandOperands):TCommandResult;
begin
     ZCMsgCallBackInterface.TextMessage('Тест производительности. запасаемя терпением',TMWOHistoryOut);
     {$IFDEF PERFOMANCELOG}programlog.LogOutStrFast('тест производительности - getonmouseobject*10000',lp_IncPos);{$ENDIF}
     //for i:=0 to 10000 do
     //       drawings.GetCurrentDWG.wa.getonmouseobject(@drawings.GetCurrentROOT.ObjArray);
     {$IFDEF PERFOMANCELOG}programlog.LogOutStrFast('тест производительности',lp_DecPos);{$ENDIF}
     ZCMsgCallBackInterface.TextMessage('Конец теста. выходим, смотрим результаты в конце лога.',TMWOHistoryOut);
     //quit_com('');
     result:=cmd_ok;
end;

function RegenZEnts_com(operands:TCommandOperands):TCommandResult;
var
    pv:pGDBObjEntity;
        ir:itrec;
    drawing:PTDrawingDef;
    DC:TDrawContext;
    lph:TLPSHandle;
begin
  lph:=lps.StartLongProcess(drawings.GetCurrentROOT.ObjArray.count,'Regenerate ZCAD entities',nil);
  drawing:=drawings.GetCurrentDwg;
  dc:=drawings.GetCurrentDwg^.CreateDrawingRC;
  pv:=drawings.GetCurrentROOT.ObjArray.beginiterate(ir);
  if pv<>nil then
  repeat
    if (pv^.GetObjType>=GDBZCadEntsMinID)and(pv^.GetObjType<=GDBZCadEntsMaxID)then
                                                                        pv^.FormatEntity(drawing^,dc);
  pv:=drawings.GetCurrentROOT.ObjArray.iterate(ir);
  lps.ProgressLongProcess(lph,ir.itc);
  until pv=nil;
  drawings.GetCurrentROOT.getoutbound(dc);
  lps.EndLongProcess(lph);

  drawings.GetCurrentDWG.wa.param.seldesc.Selectedobjcount:=0;
  drawings.GetCurrentDWG.wa.param.seldesc.OnMouseObject:=nil;
  drawings.GetCurrentDWG.wa.param.seldesc.LastSelectedObject:=nil;
  drawings.GetCurrentDWG.wa.param.lastonmouseobject:=nil;
  ZCMsgCallBackInterface.Do_GUIaction(nil,ZMsgID_GUIReturnToDefaultObject);
  clearcp;
  //redrawoglwnd;
  result:=cmd_ok;
end;

function Connection2Dot_com(operands:TCommandOperands):TCommandResult;
var
  cman:TCableManager;
  pv:PTCableDesctiptor;
  segment:PGDBObjCable;
  node:PTNodeProp;
  nodeend,nodestart:PGDBObjDevice;
  ir,ir2,ir_inNodeArray:itrec;
  pvd,pvd2:pvardesk;
  startnodename,endnodename,startnodelabel,endnodelabel:string;

  alreadywrite:TDictionary<pointer,integer>;
  inriser:boolean;
begin
  cman.init;
  cman.build;
  alreadywrite:=TDictionary<pointer,integer>.create;

  ZCMsgCallBackInterface.TextMessage('DiGraph Classes {',TMWOHistoryOut);

  pv:=cman.beginiterate(ir);
  if pv<>nil then
  begin
    repeat
    inriser:=false;
    segment:=pv^.Segments.beginiterate(ir2);
    if segment<>nil then
    repeat
    begin
      node:=segment^.NodePropArray.beginiterate(ir_inNodeArray);
      if node<>nil then begin
        if not inriser then
          nodestart:=node.DevLink;
        node:=segment^.NodePropArray.iterate(ir_inNodeArray);
        if (node<>nil)and(nodestart<>nil) then
        repeat
          nodeend:=node.DevLink;
          if nodeend<>nil then begin
          pvd:=FindVariableInEnt(nodestart,'NMO_Name');
          pvd2:=FindVariableInEnt(nodeend,'NMO_Name');
          if pvd2=nil then begin
             if FindVariableInEnt(nodeend,'RiserName')<>nil then
                inriser:=true;
          end else
            inriser:=false;
          if (pvd<>nil)and(pvd2<>nil) then begin
            startnodename:=PointerToNodeName(nodestart);
            endnodename:=PointerToNodeName(nodeend);
            startnodelabel:=pstring(pvd^.data.Instance)^;
            endnodelabel:=pstring(pvd2^.data.Instance)^;

            if not alreadywrite.ContainsKey(nodestart) then begin
              ZCMsgCallBackInterface.TextMessage(format(' %s [label="%s"]',[startnodename,startnodelabel]),TMWOHistoryOut);
              alreadywrite.add(nodestart,1);
            end;
            if not alreadywrite.ContainsKey(nodeend) then begin
              ZCMsgCallBackInterface.TextMessage(format(' %s [label="%s"]',[endnodename,endnodelabel]),TMWOHistoryOut);
              alreadywrite.add(nodeend,1);
              if endnodelabel='П1-ШУ' then
                endnodelabel:=endnodelabel;
            end;
            ZCMsgCallBackInterface.TextMessage(format(' %s->%s [label="%s"]',[startnodename,endnodename,pv^.Name]),TMWOHistoryOut);
            nodestart:=nodeend;
          end;
          end;
          {if pvd=nil then
            nodestart:=nodeend;}
        node:=segment^.NodePropArray.iterate(ir_inNodeArray);
      until node=nil;
      end;
    end;
    segment:=pv^.Segments.iterate(ir2);
    until segment=nil;
  pv:=cman.iterate(ir);
  until pv=nil;

  ZCMsgCallBackInterface.TextMessage('}',TMWOHistoryOut);
  cman.done;
  alreadywrite.free;
  result:=cmd_ok;
end;

end;

procedure startup;
//var
  // s:gdbstring;
begin
  MainSpecContentFormat.init(100);
  MainSpecContentFormat.loadfromfile(FindInSupportPath(SupportPath,'main.sf'));
  CreateCommandFastObjectPlugin(@RegenZEnts_com,'RegenZEnts',CADWG,0);
  Wire.init('El_Wire',0,0);
  commandmanager.CommandRegister(@Wire);
  pcabcom:=CreateCommandRTEdObjectPlugin(@_Cable_com_CommandStart, _Cable_com_CommandEnd,nil,@cabcomformat,@_Cable_com_BeforeClick,@_Cable_com_AfterClick,@_Cable_com_Hd,nil,'EL_Cable',0,0);

  pcabcom^.SetCommandParam(@cabcomparam,'PTELCableComParam');
  cabcomparam.Traces.Enums.init(10);
  cabcomparam.PTrace:=nil;

  CreateCommandFastObjectPlugin(@_Cable_com_Invert,'El_Cable_Invert',CADWG,0);
  CreateCommandFastObjectPlugin(@_Cable_com_Manager,'El_CableMan',CADWG,0);
  CreateCommandFastObjectPlugin(@_Cable_com_Legend,'El_Cable_Legend',CADWG,0);
  CreateCommandFastObjectPlugin(@_Cable_com_Join,'El_Cable_Join',CADWG,0);
  csel:=CreateCommandFastObjectPlugin(@_Cable_com_Select,'El_Cable_Select',CADWG,0);
  csel.CEndActionAttr:=0;
  CreateCommandFastObjectPlugin(@_Material_com_Legend,'El_Material_Legend',CADWG,0);
  CreateCommandFastObjectPlugin(@_Cable_mark_com,'KIP_Cable_Mark',CADWG,0);

  CreateCommandFastObjectPlugin(@_Ren_n_to_0n_com,'El_Cable_RenN_0N',CADWG,0);
  CreateCommandFastObjectPlugin(@_SelectMaterial_com,'SelMat',CADWG,0);
  CreateCommandFastObjectPlugin(@_test_com,'test',CADWG,0);
  CreateCommandFastObjectPlugin(@_El_ExternalKZ_com,'El_ExternalKZ',CADWG,0);
  CreateCommandFastObjectPlugin(@_AutoGenCableRemove_com,'EL_AutoGen_Cable_Remove',CADWG,0);
  CreateCommandFastObjectPlugin(@Connection2Dot_com,'Connection2Dot',CADWG,0);

  EM_SRBUILD.init('EM_SRBUILD',CADWG,0);
  EM_SEPBUILD.init('EM_SEPBUILD',CADWG,0);
  KIP_CDBuild.init('KIP_CDBuild',CADWG,0);
  KIP_LugTableBuild.init('KIP_LugTableBuild',CADWG,0);

  EM_SEPBUILD.SetCommandParam(@em_sepbuild_params,'PTBasicFinter');

  CreateCommandRTEdObjectPlugin(@ElLeaser_com_CommandStart,@Line_com_CommandEnd,nil,nil,@Line_com_BeforeClick,@El_Leader_com_AfterClick,nil,nil,'El_Leader',0,0);
  pfindcom:=CreateCommandRTEdObjectPlugin(@Find_com,nil,nil,@commformat,nil,nil,nil,nil,'El_Find',0,0);
  pfindcom.CEndActionAttr:=0;
  pfindcom^.SetCommandParam(@FindDeviceParam,'PTFindDeviceParam');

  FindDeviceParam.FindType:=tft_obozn;
  FindDeviceParam.FindString:='';
  ELLeaderComParam.Scale:=1;
  ELLeaderComParam.Size:=1;

  CreateCommandFastObjectPlugin(@VarReport_com,'VarReport',CADWG,0);
end;

procedure finalize;
begin
     MainSpecContentFormat.Done;
end;
initialization
  startup;
finalization
  debugln('{I}[UnitsFinalization] Unit "',{$INCLUDE %FILE%},'" finalization');
  finalize;
end.

