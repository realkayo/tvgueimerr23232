local StrToNumber=tonumber;local Byte=string.byte;local Char=string.char;local Sub=string.sub;local Subg=string.gsub;local Rep=string.rep;local Concat=table.concat;local Insert=table.insert;local LDExp=math.ldexp;local GetFEnv=getfenv or function()return _ENV;end ;local Setmetatable=setmetatable;local PCall=pcall;local Select=select;local Unpack=unpack or table.unpack ;local ToNumber=tonumber;local function VMCall(ByteString,vmenv,...)local DIP=1;local repeatNext;ByteString=Subg(Sub(ByteString,5),"..",function(byte)if (Byte(byte,2)==79) then repeatNext=StrToNumber(Sub(byte,1,1));return "";else local a=Char(StrToNumber(byte,16));if repeatNext then local b=Rep(a,repeatNext);repeatNext=nil;return b;else return a;end end end);local function gBit(Bit,Start,End)if End then local Res=(Bit/(2^(Start-1)))%(2^(((End-1) -(Start-1)) + 1)) ;return Res-(Res%1) ;else local Plc=2^(Start-1) ;return (((Bit%(Plc + Plc))>=Plc) and 1) or 0 ;end end local function gBits8()local a=Byte(ByteString,DIP,DIP);DIP=DIP + 1 ;return a;end local function gBits16()local a,b=Byte(ByteString,DIP,DIP + 2 );DIP=DIP + 2 ;return (b * 256) + a ;end local function gBits32()local a,b,c,d=Byte(ByteString,DIP,DIP + 3 );DIP=DIP + 4 ;return (d * 16777216) + (c * 65536) + (b * 256) + a ;end local function gFloat()local Left=gBits32();local Right=gBits32();local IsNormal=1;local Mantissa=(gBit(Right,1,20) * (2^32)) + Left ;local Exponent=gBit(Right,21,31);local Sign=((gBit(Right,32)==1) and  -1) or 1 ;if (Exponent==0) then if (Mantissa==0) then return Sign * 0 ;else Exponent=1;IsNormal=0;end elseif (Exponent==2047) then return ((Mantissa==0) and (Sign * (1/0))) or (Sign * NaN) ;end return LDExp(Sign,Exponent-1023 ) * (IsNormal + (Mantissa/(2^52))) ;end local function gString(Len)local Str;if  not Len then Len=gBits32();if (Len==0) then return "";end end Str=Sub(ByteString,DIP,(DIP + Len) -1 );DIP=DIP + Len ;local FStr={};for Idx=1, #Str do FStr[Idx]=Char(Byte(Sub(Str,Idx,Idx)));end return Concat(FStr);end local gInt=gBits32;local function _R(...)return {...},Select("#",...);end local function Deserialize()local Instrs={};local Functions={};local Lines={};local Chunk={Instrs,Functions,nil,Lines};local ConstCount=gBits32();local Consts={};for Idx=1,ConstCount do local Type=gBits8();local Cons;if (Type==1) then Cons=gBits8()~=0 ;elseif (Type==2) then Cons=gFloat();elseif (Type==3) then Cons=gString();end Consts[Idx]=Cons;end Chunk[3]=gBits8();for Idx=1,gBits32() do local Descriptor=gBits8();if (gBit(Descriptor,1,1)==0) then local Type=gBit(Descriptor,2,3);local Mask=gBit(Descriptor,4,6);local Inst={gBits16(),gBits16(),nil,nil};if (Type==0) then Inst[3]=gBits16();Inst[4]=gBits16();elseif (Type==1) then Inst[3]=gBits32();elseif (Type==2) then Inst[3]=gBits32() -(2^16) ;elseif (Type==3) then Inst[3]=gBits32() -(2^16) ;Inst[4]=gBits16();end if (gBit(Mask,1,1)==1) then Inst[2]=Consts[Inst[2]];end if (gBit(Mask,2,2)==1) then Inst[3]=Consts[Inst[3]];end if (gBit(Mask,3,3)==1) then Inst[4]=Consts[Inst[4]];end Instrs[Idx]=Inst;end end for Idx=1,gBits32() do Functions[Idx-1 ]=Deserialize();end for Idx=1,gBits32() do Lines[Idx]=gBits32();end return Chunk;end local function Wrap(Chunk,Upvalues,Env)local Instr=Chunk[1];local Proto=Chunk[2];local Params=Chunk[3];return function(...)local VIP=1;local Top= -1;local Args={...};local PCount=Select("#",...) -1 ;local function Loop()local Instr=Instr;local Proto=Proto;local Params=Params;local _R=_R;local Vararg={};local Lupvals={};local Stk={};for Idx=0,PCount do if (Idx>=Params) then Vararg[Idx-Params ]=Args[Idx + 1 ];else Stk[Idx]=Args[Idx + 1 ];end end local Varargsz=(PCount-Params) + 1 ;local Inst;local Enum;while true do Inst=Instr[VIP];Enum=Inst[1];if (Enum<=10) then if (Enum<=4) then if (Enum<=1) then if (Enum==0) then local NewProto=Proto[Inst[3]];local NewUvals;local Indexes={};NewUvals=Setmetatable({},{__index=function(_,Key)local Val=Indexes[Key];return Val[1][Val[2]];end,__newindex=function(_,Key,Value)local Val=Indexes[Key];Val[1][Val[2]]=Value;end});for Idx=1,Inst[4] do VIP=VIP + 1 ;local Mvm=Instr[VIP];if (Mvm[1]==18) then Indexes[Idx-1 ]={Stk,Mvm[3]};else Indexes[Idx-1 ]={Upvalues,Mvm[3]};end Lupvals[ #Lupvals + 1 ]=Indexes;end Stk[Inst[2]]=Wrap(NewProto,NewUvals,Env);else Stk[Inst[2]]=Wrap(Proto[Inst[3]],nil,Env);end elseif (Enum<=2) then local A=Inst[2];Stk[A]=Stk[A](Unpack(Stk,A + 1 ,Top));elseif (Enum==3) then local A=Inst[2];Stk[A](Unpack(Stk,A + 1 ,Inst[3]));else local A=Inst[2];Stk[A]=Stk[A]();end elseif (Enum<=7) then if (Enum<=5) then Stk[Inst[2]]=Stk[Inst[3]][Inst[4]];elseif (Enum>6) then Stk[Inst[2]]=Upvalues[Inst[3]];else do return;end end elseif (Enum<=8) then Stk[Inst[2]]=Inst[3];elseif (Enum>9) then local A=Inst[2];local T=Stk[A];for Idx=A + 1 ,Inst[3] do Insert(T,Stk[Idx]);end else local A=Inst[2];local B=Stk[Inst[3]];Stk[A + 1 ]=B;Stk[A]=B[Inst[4]];end elseif (Enum<=16) then if (Enum<=13) then if (Enum<=11) then Stk[Inst[2]][Inst[3]]=Inst[4];elseif (Enum==12) then Stk[Inst[2]][Inst[3]]=Stk[Inst[4]];else Stk[Inst[2]]();end elseif (Enum<=14) then VIP=Inst[3];elseif (Enum==15) then local A=Inst[2];local Results,Limit=_R(Stk[A](Unpack(Stk,A + 1 ,Inst[3])));Top=(Limit + A) -1 ;local Edx=0;for Idx=A,Top do Edx=Edx + 1 ;Stk[Idx]=Results[Edx];end else local A=Inst[2];Stk[A]=Stk[A](Unpack(Stk,A + 1 ,Inst[3]));end elseif (Enum<=19) then if (Enum<=17) then if (Stk[Inst[2]]==Inst[4]) then VIP=VIP + 1 ;else VIP=Inst[3];end elseif (Enum==18) then Stk[Inst[2]]=Stk[Inst[3]];else Stk[Inst[2]]=Env[Inst[3]];end elseif (Enum<=20) then local A=Inst[2];local T=Stk[A];local B=Inst[3];for Idx=1,B do T[Idx]=Stk[A + Idx ];end elseif (Enum==21) then Env[Inst[3]]=Stk[Inst[2]];else Stk[Inst[2]]={};end VIP=VIP + 1 ;end end A,B=_R(PCall(Loop));if  not A[1] then local line=Chunk[4][VIP] or "?" ;error("Script error at ["   .. line   .. "]:"   .. A[2] );else return Unpack(A,2,B);end end;end return Wrap(Deserialize(),{},vmenv)(...);end VMCall("LOL!6E3O0003043O0067616D65030A3O0047657453657276696365030A3O0052756E53657276696365030A3O006C6F6164737472696E6703073O00482O747047657403473O00682O7470733A2O2F7261772E67697468756275736572636F6E74656E742E636F6D2F6F6E6C796B61796F2F544E462D62792D6B61796F2F6D61696E2F747261636572732E6C756103433O00682O7470733A2O2F7261772E67697468756275736572636F6E74656E742E636F6D2F6F6E6C796B61796F2F544E462D62792D6B61796F2F6D61696E2F6573702E6C756103403O00682O7470733A2O2F7261772E67697468756275736572636F6E74656E742E636F6D2F73686C6578776172652F5261796669656C642F6D61696E2F736F7572636503063O0061696D626F74033C3O00682O7470733A2O2F6769746875622E636F6D2F52756E44544D2F5A2O65726F782D41696D626F742F7261772F6D61696E2F6C6962726172792E6C756103073O00456E61626C6564010003073O00506C61796572732O0103093O005465616D436865636B030A3O00416C697665436865636B2O033O00464F56026O00594003073O0053686F77464F56030F3O005669736962696C697479436865636B030E3O00464F56436972636C65436F6C6F7203063O00436F6C6F723303073O0066726F6D524742025O00E06740026O004840025O0060634003023O005F47030A3O0045535056697369626C65030E3O005472616365727356697369626C65030C3O0043726561746557696E646F7703043O004E616D6503173O00544E462076312E30207C206279206B61796F2335363934030C3O004C6F6164696E675469746C6503083O00544E462056312E30030F3O004C6F6164696E675375627469746C65030C3O006279206B61796F233536393403133O00436F6E66696775726174696F6E536176696E67030A3O00466F6C6465724E616D650003083O0046696C654E616D6503083O00544E462D4B61796F03073O00446973636F726403063O00496E76697465030A3O0053526475644D6A795134030D3O0052656D656D6265724A6F696E7303093O004B657953797374656D030B3O004B657953652O74696E677303053O005469746C6503153O00544E462076312E30206279206B61796F233536393403083O005375627469746C6503083O00544E462076312E3003043O004E6F7465032E3O00656E747265206E6F206E6F2O736F20646973636F72642028646973636F72642E2O672F53526475644D6A7951342903053O006B61796F2D03073O00536176654B6579030F3O00477261624B657946726F6D536974652O033O004B657903073O006B68346A732O6903093O0043726561746554616203093O005072696E636970616C034O0003073O005669737561697303063O0053657276657203063O004F7574726F73030D3O0043726561746553656374696F6E030F3O00506F6465726573205669737561697303133O00486162696C696461646573206465204D697261030C3O00437265617465546F2O676C6503063O0041696D626F74030C3O0043752O72656E7456616C756503043O00466C616703073O00546F2O676C653103083O0043612O6C6261636B030C3O00437265617465536C6964657203113O0041696D626F7420536D2O6F74686E652O7303053O0052616E6765028O00026O00244003093O00496E6372656D656E74026O00F03F03063O0053752O66697803013O002003073O00536C6964657231031E3O0041696D412O736973742028656D20646573656E766F6C76696D656E746F292O033O00466F76030B3O004D6F737472617220466F76030E3O0054616D616E686F20646F20466F76026O004940025O00407F40030D3O005665726966696361646F726573032B3O0041696D626F74205669736962696C69747920436865636B2028657374616D6F7320612O72756D616E646F29030C3O005465616D20436865636B65722O033O0045737003113O00437265617465436F6C6F725069636B6572030A3O00436F7220646F2045535003053O00436F6C6F7203093O0054657874436F6C6F72030C3O00436F6C6F725069636B65723103073O0054726163657273030D3O00436F7220646F20547261636572030B3O00547261636572436F6C6F72030A3O00436F7220646F20466F7603103O005365727665722046756E6374696F6E73030C3O0043726561746542752O746F6E03243O0043726173686172207365727665722028657374616D6F732074726162616C68616E646F2903123O0066756EE7F5657320616C6561746F72696173031A3O005374612O66206465746563746F7220286175746F2D6B69636B2903053O0053702O6564026O002C40026O0054400014012O0012133O00013O0020095O0002001208000200034O00103O00020002001213000100043O001213000200013O002009000200020005001208000400064O000F000200044O000200013O00022O000D000100010001001213000100043O001213000200013O002009000200020005001208000400074O000F000200044O000200013O00022O000D000100010001001213000100043O001213000200013O002009000200020005001208000400084O000F000200044O000200013O00022O0004000100010002001213000200043O001213000300013O0020090003000300050012080005000A4O000F000300054O000200023O00022O0004000200010002001215000200093O001213000200093O00300B0002000B000C001213000200093O00300B0002000D000E001213000200093O00300B0002000F000E001213000200093O00300B00020010000E001213000200093O00300B000200110012001213000200093O00300B00020013000C001213000200093O00300B00020014000C001213000200093O001213000300163O002005000300030017001208000400183O001208000500193O0012080006001A4O001000030006000200100C0002001500030012130002001B3O00300B0002001C000C0012130002001B3O00300B0002001D000C00200900020001001E2O001600043O000700300B0004001F002000300B00040021002200300B0004002300242O001600053O000300300B0005000B000C00300B00050026002700300B00050028002900100C0004002500052O001600053O000300300B0005000B000E00300B0005002B002C00300B0005002D000E00100C0004002A000500300B0004002E000E2O001600053O000700300B00050030003100300B00050032003300300B00050034003500300B00050028003600300B00050037000C00300B00050038000C00300B00050039003A00100C0004002F00052O001000020004000200200900030002003B0012080005003C3O0012080006003D4O001000030006000200200900040002003B0012080006003E3O0012080007003D4O001000040007000200200900050002003B0012080007003F3O0012080008003D4O001000050008000200200900060002003B001208000800403O0012080009003D4O0010000600090002002009000700040041001208000900424O0010000700090002002009000800030041001208000A00434O00100008000A00020020090009000300442O0016000B3O000400300B000B001F004500300B000B0046000C00300B000B00470048000201000C5O00100C000B0049000C2O00100009000B0002002009000A0003004A2O0016000C3O000700300B000C001F004B2O0016000D00023O001208000E004D3O001208000F004E4O0014000D0002000100100C000C004C000D00300B000C004F005000300B000C0051005200300B000C0046004D00300B000C00470053000201000D00013O00100C000C0049000D2O0010000A000C0002002009000B000300442O0016000D3O000400300B000D001F005400300B000D0046000C00300B000D00470048000201000E00023O00100C000D0049000E2O0010000B000D0002002009000C00030041001208000E00554O0010000C000E0002002009000D000300442O0016000F3O000400300B000F001F005600300B000F0046000C00300B000F0047004800062O00100003000100012O00123O00013O00100C000F004900102O0010000D000F0002002009000E0003004A2O001600103O000700300B0010001F00572O0016001100023O001208001200583O001208001300594O001400110002000100100C0010004C001100300B0010004F005000300B00100051005200300B00100046001200300B001000470053000201001100043O00100C0010004900112O0010000E00100002002009000F000300410012080011005A4O0010000F001100020020090010000300442O001600123O000400300B0012001F005B00300B00120046000C00300B001200470048000201001300053O00100C0012004900132O00100010001200020020090011000300442O001600133O000400300B0013001F005C00300B00130046000E00300B001300470048000201001400063O00100C0013004900142O00100011001300020020090012000400442O001600143O000400300B0014001F005D00300B00140046000C00300B001400470048000201001500073O00100C0014004900152O001000120014000200200900130004005E2O001600153O000400300B0015001F005F0012130016001B3O00200500160016006100100C00150060001600300B001500470062000201001600083O00100C0015004900162O0010001300150002002009001400040041001208001600634O00100014001600020020090015000400442O001600173O000400300B0017001F006300300B00170046000C00300B001700470048000201001800093O00100C0017004900182O001000150017000200200900160004005E2O001600183O000400300B0018001F00640012130019001B3O00200500190019006500100C00180060001900300B0018004700620002010019000A3O00100C0018004900192O0010001600180002002009001700040041001208001900554O001000170019000200200900180004005E2O0016001A3O000400300B001A001F0066001213001B00163O002005001B001B0017001208001C00183O001208001D00193O001208001E001A4O0010001B001E000200100C001A0060001B00300B001A00470062000201001B000B3O00100C001A0049001B2O00100018001A0002002009001900050041001208001B00674O00100019001B0002002009001A000500682O0016001C3O000200300B001C001F0069000201001D000C3O00100C001C0049001D2O0010001A001C0002002009001B00060041001208001D006A4O0010001B001D0002002009001C000600442O0016001E3O000400300B001E001F006B00300B001E0046000C00300B001E00470048000201001F000D3O00100C001E0049001F2O0010001C001E0002002009001D0006004A2O0016001F3O000700300B001F001F006C2O0016002000023O0012080021006D3O0012080022006E4O001400200002000100100C001F004C002000300B001F004F005000300B001F0051005200300B001F0046006D00300B001F004700530002010020000E3O00100C001F004900202O0010001D001F00022O00063O00013O000F3O00023O0003063O0061696D626F7403073O00456E61626C656401033O001213000100013O00100C000100024O00063O00017O00033O00183O00183O00193O00023O0003063O0061696D626F7403093O00536D2O6F7468696E6701033O001213000100013O00100C000100024O00063O00017O00033O001B3O001B3O001C7O002O014O00063O00017O00013O001E3O00113O0003063O0061696D626F7403073O0053686F77464F562O0103063O004E6F7469667903053O005469746C65030C3O00417669736F206465204C616703073O00436F6E74656E7403523O00446569786172206F20464F56206C696761646F20706F646520636175736172206C616720656D20706320667261636F2C206465736174697665206361736F207469766572207175656461206465206670732103083O004475726174696F6E026O00244003053O00496D616765022O0080FA0D2EC54103073O00416374696F6E7303063O0049676E6F726503043O004E616D652O033O006F6B2103083O0043612O6C6261636B01143O001213000100013O00100C000100023O0026113O00130001000300040E3O001300012O000700015O0020090001000100042O001600033O000500300B00030005000600300B00030007000800300B00030009000A00300B0003000B000C2O001600043O00012O001600053O000200300B0005000F001000020100065O00100C00050011000600100C0004000E000500100C0003000D00042O00030001000300012O00063O00013O00018O00014O00063O00017O00013O00243O00143O00213O00213O00223O00223O00233O00233O00233O00233O00233O00233O00233O00233O00233O00233O00243O00243O00243O00243O00233O00263O00023O0003063O0061696D626F742O033O00464F5601033O001213000100013O00100C000100024O00063O00017O00033O00283O00283O00297O002O014O00063O00017O00013O002C3O00033O0003023O005F4703093O005465616D436865636B03063O0061696D626F7401053O001213000100013O00100C000100023O001213000100033O00100C000100024O00063O00017O00053O002E3O002E3O002F3O002F3O00303O00023O0003023O005F47030A3O0045535056697369626C6501033O001213000100013O00100C000100024O00063O00017O00033O00323O00323O00333O00023O0003023O005F4703093O0054657874436F6C6F7201033O001213000100013O00100C000100024O00063O00017O00033O00353O00353O00363O00023O0003023O005F47030E3O005472616365727356697369626C6501033O001213000100013O00100C000100024O00063O00017O00033O00393O00393O003A3O00023O0003023O005F47030B3O00547261636572436F6C6F7201033O001213000100013O00100C000100024O00063O00017O00033O003C3O003C3O003D3O00023O0003063O0061696D626F74030E3O00464F56436972636C65436F6C6F7201033O001213000100013O00100C000100024O00063O00017O00033O00403O00403O00418O00014O00063O00017O00013O00447O002O014O00063O00017O00013O00473O00063O0003043O0067616D6503073O00506C6179657273030B3O004C6F63616C506C6179657203093O0043686172616374657203083O0048756D616E6F696403093O0057616C6B53702O656401073O001213000100013O00200500010001000200200500010001000300200500010001000400200500010001000500100C000100064O00063O00017O00073O00493O00493O00493O00493O00493O00493O004A3O0014012O00013O00013O00013O00013O00023O00023O00023O00023O00023O00023O00023O00033O00033O00033O00033O00033O00033O00033O00043O00043O00043O00043O00043O00043O00043O00053O00053O00053O00053O00053O00053O00053O00053O00063O00063O00073O00073O00083O00083O00093O00093O000A3O000A3O000B3O000B3O000C3O000C3O000D3O000D3O000D3O000D3O000D3O000D3O000D3O000D3O000E3O000E3O000F3O000F3O00103O00103O00103O00103O00103O00103O00103O00103O00103O00103O00103O00103O00103O00103O00103O00103O00103O00103O00103O00103O00103O00103O00103O00103O00103O00103O00113O00113O00113O00113O00123O00123O00123O00123O00133O00133O00133O00133O00143O00143O00143O00143O00153O00153O00153O00163O00163O00163O00173O00173O00173O00173O00173O00193O00193O00173O001A3O001A3O001A3O001A3O001A3O001A3O001A3O001A3O001A3O001A3O001A3O001A3O001C3O001C3O001A3O001D3O001D3O001D3O001D3O001D3O001E3O001E3O001D3O001F3O001F3O001F3O00203O00203O00203O00203O00203O00263O00263O00263O00203O00273O00273O00273O00273O00273O00273O00273O00273O00273O00273O00273O00273O00293O00293O00273O002A3O002A3O002A3O002B3O002B3O002B3O002B3O002B3O002C3O002C3O002B3O002D3O002D3O002D3O002D3O002D3O00303O00303O002D3O00313O00313O00313O00313O00313O00333O00333O00313O00343O00343O00343O00343O00343O00343O00343O00363O00363O00343O00373O00373O00373O00383O00383O00383O00383O00383O003A3O003A3O00383O003B3O003B3O003B3O003B3O003B3O003B3O003B3O003D3O003D3O003B3O003E3O003E3O003E3O003F3O003F3O003F3O003F3O003F3O003F3O003F3O003F3O003F3O003F3O003F3O00413O00413O003F3O00423O00423O00423O00433O00433O00433O00443O00443O00433O00453O00453O00453O00463O00463O00463O00463O00463O00473O00473O00463O00483O00483O00483O00483O00483O00483O00483O00483O00483O00483O00483O00483O004A3O004A3O00483O004A3O00",GetFEnv(),...);
