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
{**
@author(Vladimir Bobrov)
}

unit uzvslagcab;
{$INCLUDE def.inc}
interface
uses
     sysutils,

     uzccommandsimpl,    //тут реализация объекта CommandRTEdObject
     uzccommandsabstract,//базовые объявления для команд
     uzbtypesbase,       //базовые типы
     uzccommandsmanager, //менеджер команд

     uzvcom,             //
     uzvnum,
     uzvtreedevice,      //новая механизм кабеле прокладки на основе Дерева
     uzvtmasterdev,
     uzvagensl,
     uzvtestdraw, // тестовые рисунки

     uzcinterface,
     uzctnrvectorgdbstring,
     uzbgeomtypes,
     uzegeometry,

     typinfo,
     gzctnrvector,
     uzvconsts,
     uzcutils,
     Varman;             //Зкадовский RTTI

type
Tuzvslagcab_com=object(CommandRTEdObject)//определяем тип - объект наследник базового объекта "динамической" команды
             procedure CommandStart(Operands:TCommandOperands);virtual;//переопределяем метод вызываемый при старте команды
             //procedure CommandEnd; virtual;//переопределяем метод вызываемый при окончании команды
             //procedure CommandCancel; virtual;//переопределяем метод вызываемый при отмене команды

             procedure visualGlobalGraph(pdata:GDBPlatformint); virtual;//построение графа и его визуализация

             procedure visualGraphDevice(pdata:GDBPlatformint); virtual;//построение всех графов и его визуализация

             procedure cablingGraphDevice(pdata:GDBPlatformint); virtual;//построение всех графов и его визуализация

             procedure cablingNewGraphDevice(pdata:GDBPlatformint); virtual;//построение всех Новых графов и его визуализация

            end;
PTuzvslagcabComParams=^TuzvslagcabComParams;//указатель на тип данных параметров команды. зкад работает с ними через указатель

TsettingVizCab=packed record
  sErrors:gdbboolean;
  vizNumMetric:gdbboolean;
  vizFullTreeCab:gdbboolean;
  vizEasyTreeCab:gdbboolean;
end;

TuzvslagcabComParams=packed record       //определяем параметры команды которые будут видны в инспекторе во время выполнения команды
                                      //регистрировать их будем паскалевским RTTI
                                      //не через экспорт исходников и парсинг файла с определениями типов
  NamesList:TEnumData;//это тип для отображения списков в инспекторе
  //nameSL:gdbstring;
  accuracy:gdbdouble;
  metricDev:gdbboolean;
  settingVizCab:TsettingVizCab;

end;
const
  Epsilon=0.2;

var
 uzvslagcab_com:Tuzvslagcab_com;//определяем экземпляр нашей команды
 uzvslagcabComParams:TuzvslagcabComParams;//определяем экземпляр параметров нашей команды

 graphCable:TGraphBuilder;        //созданый граф
 listHeadDevice:TListHeadDevice;  //список головных устройств с подключенными к ним устройствами
 listAllGraph:TListAllGraph;      //список графов




implementation

procedure Tuzvslagcab_com.CommandStart(Operands:TCommandOperands);
var
 listSLname:TGDBlistSLname;
 nameSL:string;
begin
  //создаем командное меню из 3х пунктов
  commandmanager.DMAddMethod('Визуализировать трассу','Позволяет просмотреть трассу, места пересечения и места подключения',visualGlobalGraph);

  commandmanager.DMAddMethod('Визуализировать кабели','Визуализирует прохождения кабелей по трассам',visualGraphDevice);

  commandmanager.DMAddMethod('Проложить кабели','Проложить кабели по трассам',cablingGraphDevice);

  commandmanager.DMAddMethod('Проложить кабели по новому','Проложить кабели по новому по трассам',cablingNewGraphDevice);

  ///***заполняем поле имени суперлинии
  uzvslagcabComParams.NamesList.Enums.Clear;

  uzvslagcabComParams.NamesList.Enums.PushBackData(vItemAllSLInspector);// добавляем "***"
  listSLname:=TGDBlistSLname.Create;
  uzvcom.getListSuperline(listSLname);
  for nameSL in listSLname do
     uzvslagcabComParams.NamesList.Enums.PushBackData(nameSL);//заполняем

  //показываем командное меню
  commandmanager.DMShow;


  //не забываем вызвать метод родителя, там еще много что должно выполниться
  inherited CommandStart('');
end;

procedure Tuzvslagcab_com.visualGlobalGraph(pdata:GDBPlatformint);
var
 i,m,counterColor:integer;
 UndoMarcerIsPlazed:boolean;
 nameSL:string;
 listSLname:TGDBlistSLname;
 graphBuilderInfo:TListGraphBuilder;
 isVisualVertex:boolean;
begin

  listAllGraph:=TListAllGraph.Create;

  //Получаем имя суперлинии выбраное в меню
  nameSL:=pstring(uzvslagcabComParams.NamesList.Enums.getDataMutable(integer(uzvslagcabComParams.NamesList.selected)))^;

  listSLname:=TGDBlistSLname.Create;
  if nameSL = vItemAllSLInspector then
        uzvcom.getListSuperline(listSLname) // Создаем список всех суперлиний
  else
        listSLname.PushBack(nameSL);        // Создаем список из одной суперлинии

  //Строим граф зная имя суперлиний
  for nameSL in listSLname do
   begin
     graphBuilderInfo.graph:=uzvcom.graphBulderFunc(uzvslagcabComParams.accuracy,nameSL);
     graphBuilderInfo.nameSuperLine:=nameSL;
     listAllGraph.PushBack(graphBuilderInfo);
   end;

  //Визуализация графа
  UndoMarcerIsPlazed:=false;
  zcPlaceUndoStartMarkerIfNeed(UndoMarcerIsPlazed,'Visualisation Graph');

  counterColor:=1;
  isVisualVertex:=true;
      for graphBuilderInfo in listAllGraph do
       begin
         //Строим граф зная имя суперлиний
          if counterColor=6 then
             counterColor:=1;
          for i:=0 to graphBuilderInfo.graph.listEdge.Size-1 do
            uzvcom.visualGraphEdge(graphBuilderInfo.graph.listEdge[i].VPoint1,graphBuilderInfo.graph.listEdge[i].VPoint2,counterColor,vSystemVisualLayerName);

          if isVisualVertex then begin
            for i:=0 to graphBuilderInfo.graph.listVertex.Size-1 do
              begin
                 m:=counterColor;
                 if graphBuilderInfo.graph.listVertex[i].deviceEnt <> nil then m:=6;
                 uzvcom.visualGraphVertex(graphBuilderInfo.graph.listVertex[i].centerPoint,1,m,vSystemVisualLayerName);
              end;
              isVisualVertex:=false;
          end;
          inc(counterColor);
       end;


  zcPlaceUndoEndMarkerIfNeed(UndoMarcerIsPlazed);
  listAllGraph.Destroy;
  zcRedrawCurrentDrawing;
  Commandmanager.executecommandend;
end;


procedure Tuzvslagcab_com.visualGraphDevice(pdata:GDBPlatformint);
var
 i,j,counterColor:integer;
 UndoMarcerIsPlazed:boolean;
 nameSL:string;
 listError:TListError;
 errorInfo:TErrorInfo;
 listSLname:TGDBlistSLname;
 listAllSLname:TGDBlistSLname;
 pConnect,fTreeVertex,eTreeVertex:GDBVertex;
 graphBuilderInfo:TListGraphBuilder;

 listMasterDevice:TVectorOfMasterDevice;
begin

  //создаем список ошибок
  listError:=TListError.Create;
  listAllGraph:=TListAllGraph.Create;

    //Получаем имя суперлинии выбраное в меню
  nameSL:=pstring(uzvslagcabComParams.NamesList.Enums.getDataMutable(integer(uzvslagcabComParams.NamesList.selected)))^;

  listSLname:=TGDBlistSLname.Create;
  listAllSLname:=TGDBlistSLname.Create;
  if nameSL = vItemAllSLInspector then begin
        uzvcom.getListSuperline(listSLname);
        uzvcom.getListSuperline(listAllSLname);
  end
  else begin
        listSLname.PushBack(nameSL);
        uzvcom.getListSuperline(listAllSLname);
  end;

  //Строим граф зная имя суперлиний
  for nameSL in listSLname do
   begin
     graphBuilderInfo.graph:=uzvcom.graphBulderFunc(uzvslagcabComParams.accuracy,nameSL);
     graphBuilderInfo.nameSuperLine:=nameSL;
     listAllGraph.PushBack(graphBuilderInfo);
   end;


  UndoMarcerIsPlazed:=false;
  zcPlaceUndoStartMarkerIfNeed(UndoMarcerIsPlazed,'Visualisation Tree Device');

  //Ищем ошибки
  //errorSearchAllParam(listAllGraph[0].graph,uzvslagcabComParams.accuracy,listError,listSLname);

  //uzvtreedevice.errorSearchList(listAllGraph[0].graph,uzvslagcabComParams.accuracy,listError,listSLname);
  uzvtreedevice.errorList(listAllGraph,uzvslagcabComParams.accuracy,listError,listSLname,listAllSLname);

  //**Визуализация ошибок и проверка ошибок
  if uzvslagcabComParams.settingVizCab.sErrors then begin
    for errorInfo in listError do
      begin
        ZCMsgCallBackInterface.TextMessage(errorInfo.name + ' - ошибка: ' + errorInfo.text,TMWOHistoryOut);
        if getPointConnector(errorInfo.device,pConnect) then
              uzvcom.visualGraphError(pConnect,4,6,vSystemVisualLayerName);
      end;
      listError.Destroy;
   end;

    if uzvslagcabComParams.settingVizCab.vizFullTreeCab then
       if commandmanager.get3dpoint('Input tree visualization coordinates',fTreeVertex) then begin
         ZCMsgCallBackInterface.TextMessage('Ok',TMWOHistoryOut);
       end
       else
         ZCMsgCallBackInterface.TextMessage('Coordinate entry canceled!!!',TMWOHistoryOut);


   if uzvslagcabComParams.settingVizCab.vizEasyTreeCab then
         if commandmanager.get3dpoint('Input easy tree visualization coordinates',eTreeVertex) then begin
           ZCMsgCallBackInterface.TextMessage('Ok',TMWOHistoryOut);
         end
         else
           ZCMsgCallBackInterface.TextMessage('Coordinate entry canceled!!!',TMWOHistoryOut);

        fTreeVertex:=uzegeometry.CreateVertex(0,0,0);
        eTreeVertex:=uzegeometry.CreateVertex(0,10000,0);
   for graphBuilderInfo in listAllGraph do
     begin
       listMasterDevice:=uzvtreedevice.buildListAllConnectDevice(graphBuilderInfo.graph,uzvslagcabComParams.accuracy,listError);

       uzvtreedevice.visualGraphConnection(graphBuilderInfo.graph,listMasterDevice,uzvslagcabComParams.settingVizCab.vizFullTreeCab,uzvslagcabComParams.settingVizCab.vizEasyTreeCab,fTreeVertex,eTreeVertex);

       uzvtreedevice.visualMasterGroupLine(graphBuilderInfo.graph,listMasterDevice,uzvslagcabComParams.metricDev,uzvslagcabComParams.accuracy*7,uzvslagcabComParams.settingVizCab.vizNumMetric);

       //uzvtreedevice.cabelingMasterGroupLine(graphBuilderInfo.graph,listMasterDevice,uzvslagcabComParams.metricDev);
     end;

  zcPlaceUndoEndMarkerIfNeed(UndoMarcerIsPlazed);
  zcRedrawCurrentDrawing;

  Commandmanager.executecommandend;
end;

procedure Tuzvslagcab_com.cablingGraphDevice(pdata:GDBPlatformint);
var
 i,j,counterColor:integer;
 UndoMarcerIsPlazed:boolean;
 nameSL:string;
 listError:TListError;
 errorInfo:TErrorInfo;
 listSLname:TGDBlistSLname;
 pConnect:GDBVertex;
 graphBuilderInfo:TListGraphBuilder;

 listMasterDevice:TVectorOfMasterDevice;
begin
  //тут делаем чтонибудь что будет усполнено по нажатию DoSomething2
  //выполним Commandmanager.executecommandend;
  //эту кнопку можно нажать 1 раз

  //создаем список ошибок
  listError:=TListError.Create;
  listAllGraph:=TListAllGraph.Create;

    //Получаем имя суперлинии выбраное в меню
  nameSL:=pstring(uzvslagcabComParams.NamesList.Enums.getDataMutable(integer(uzvslagcabComParams.NamesList.selected)))^;

  listSLname:=TGDBlistSLname.Create;
  if nameSL = vItemAllSLInspector then
        uzvcom.getListSuperline(listSLname)
  else
        listSLname.PushBack(nameSL);

  //Строим граф зная имя суперлиний
  for nameSL in listSLname do
   begin
     graphBuilderInfo.graph:=uzvcom.graphBulderFunc(uzvslagcabComParams.accuracy,nameSL);
     graphBuilderInfo.nameSuperLine:=nameSL;
     listAllGraph.PushBack(graphBuilderInfo);
   end;


  UndoMarcerIsPlazed:=false;
  zcPlaceUndoStartMarkerIfNeed(UndoMarcerIsPlazed,'Visualisation Tree Device');

  //Ищем ошибки
  uzvtreedevice.errorSearchList(listAllGraph[0].graph,uzvslagcabComParams.accuracy,listError,listSLname);

  //**Визуализация ошибок и проверка ошибок
  if uzvslagcabComParams.settingVizCab.sErrors then begin
    for errorInfo in listError do
      begin
        ZCMsgCallBackInterface.TextMessage(errorInfo.name + ' - ошибка: ' + errorInfo.text,TMWOHistoryOut);
        if getPointConnector(errorInfo.device,pConnect) then
              uzvcom.visualGraphError(pConnect,4,6,vSystemVisualLayerName);
      end;
      listError.Destroy;
   end;


   for graphBuilderInfo in listAllGraph do
     begin
       listMasterDevice:=uzvtreedevice.buildListAllConnectDevice(graphBuilderInfo.graph,uzvslagcabComParams.accuracy,listError);

       //uzvtreedevice.visualMasterGroupLine(graphBuilderInfo.graph,listMasterDevice,uzvslagcabComParams.metricDev,uzvslagcabComParams.accuracy*7,uzvslagcabComParams.settingVizCab.vizNumMetric);

       uzvtreedevice.cabelingMasterGroupLine(graphBuilderInfo.graph,listMasterDevice,uzvslagcabComParams.metricDev);
     end;

  zcPlaceUndoEndMarkerIfNeed(UndoMarcerIsPlazed);
  zcRedrawCurrentDrawing;

  Commandmanager.executecommandend;
end;


procedure Tuzvslagcab_com.cablingNewGraphDevice(pdata:GDBPlatformint);
var
 i,j,counterColor:integer;
 UndoMarcerIsPlazed:boolean;
 nameSL:string;
 listError:TListError;
 errorInfo:TErrorInfo;
 listSLname:TGDBlistSLname;
 pConnect:GDBVertex;
 graphBuilderInfo:TListGraphBuilder;

 listMasterDevice:TVectorOfMasterDevice;
begin
  //тут делаем чтонибудь что будет усполнено по нажатию DoSomething2
  //выполним Commandmanager.executecommandend;
  //эту кнопку можно нажать 1 раз

  //создаем список ошибок
  listError:=TListError.Create;
  listAllGraph:=TListAllGraph.Create;

    //Получаем имя суперлинии выбраное в меню
  nameSL:=pstring(uzvslagcabComParams.NamesList.Enums.getDataMutable(integer(uzvslagcabComParams.NamesList.selected)))^;

  listSLname:=TGDBlistSLname.Create;
  if nameSL = vItemAllSLInspector then
        uzvcom.getListSuperline(listSLname)
  else
        listSLname.PushBack(nameSL);

  //Строим граф зная имя суперлиний
  for nameSL in listSLname do
   begin
     graphBuilderInfo.graph:=uzvcom.graphBulderFunc(uzvslagcabComParams.accuracy,nameSL);
     graphBuilderInfo.nameSuperLine:=nameSL;
     listAllGraph.PushBack(graphBuilderInfo);
   end;


  UndoMarcerIsPlazed:=false;
  zcPlaceUndoStartMarkerIfNeed(UndoMarcerIsPlazed,'Visualisation Tree Device');

  //Ищем ошибки
  uzvtreedevice.errorSearchList(listAllGraph[0].graph,uzvslagcabComParams.accuracy,listError,listSLname);

  //**Визуализация ошибок и проверка ошибок
  if uzvslagcabComParams.settingVizCab.sErrors then begin
    for errorInfo in listError do
      begin
        ZCMsgCallBackInterface.TextMessage(errorInfo.name + ' - ошибка: ' + errorInfo.text,TMWOHistoryOut);
        if getPointConnector(errorInfo.device,pConnect) then
              uzvcom.visualGraphError(pConnect,4,6,vSystemVisualLayerName);
      end;
      listError.Destroy;
   end;


   for graphBuilderInfo in listAllGraph do
     begin
       listMasterDevice:=uzvtreedevice.buildListAllConnectDeviceNew(graphBuilderInfo.graph,uzvslagcabComParams.accuracy,listError);

       //uzvtreedevice.visualMasterGroupLine(graphBuilderInfo.graph,listMasterDevice,uzvslagcabComParams.metricDev,uzvslagcabComParams.accuracy*7,uzvslagcabComParams.settingVizCab.vizNumMetric);

       //uzvtreedevice.cabelingMasterGroupLine(graphBuilderInfo.graph,listMasterDevice,uzvslagcabComParams.metricDev);
     end;

  zcPlaceUndoEndMarkerIfNeed(UndoMarcerIsPlazed);
  zcRedrawCurrentDrawing;

  Commandmanager.executecommandend;
end;


initialization
  //начальные значения параметров
  uzvslagcabComParams.NamesList.Enums.init(10);//инициализируем список
  //uzvslagcabComParams.NamesList.Enums.Clear;//потом при нужде его так очищаем
  //uzvslagcabComParams.NamesList.Enums.PushBackData('нуль');//заполняем
  //uzvslagcabComParams.NamesList.Enums.PushBackData('адин');//заполняем
  //uzvslagcabComParams.NamesList.Enums.PushBackData('тва');//заполняем
  //uzvslagcabComParams.NamesList.Selected:=1;//изначально будет выбран 'адин'

  //uzvslagcabComParams.nameSL:='-';
  uzvslagcabComParams.accuracy:=0.3;
  uzvslagcabComParams.metricDev:=true;
  uzvslagcabComParams.settingVizCab.sErrors:=true;
  uzvslagcabComParams.settingVizCab.vizNumMetric:=true;


  SysUnit.RegisterType(TypeInfo(PTuzvslagcabComParams));//регистрируем тип данных в зкадном RTTI

  SysUnit.SetTypeDesk(TypeInfo(TsettingVizCab),['Проверять ошибки','Пронумировать устройства','Построить полное дерево','Построить простое дерево']);//Даем человечьи имена параметрам
  SysUnit.SetTypeDesk(TypeInfo(TuzvslagcabComParams),['Имя суперлинии','Погрешность','Метрика нумерации по типам датчиков','Визуализация настройки']);//Даем человечьи имена параметрам

  uzvslagcab_com.init('slagcab',CADWG,0);//инициализируем команду
  uzvslagcab_com.SetCommandParam(@uzvslagcabComParams,'PTuzvslagcabComParams');//привязываем параметры к команде
finalization
  uzvslagcabComParams.NamesList.Enums.done;//незабываем убить проинициализированный объект
end.
