let SimpleArg = { name : Text, type : Text }

let SimpleArgV2 = SimpleArg ⩓ { internalType : Text }

let ComplexArg = SimpleArg ⩓ { components : List SimpleArg }

let ComplexArgV2 = SimpleArgV2 ⩓ { components : List SimpleArgV2 }

let FunArg =
      < Simple : SimpleArg
      | Complex : ComplexArg
      | SimpleV2 : SimpleArgV2
      | ComplexV2 : ComplexArgV2
      >

-- TODO: Make EvArg into a Union of EvArg | EvArgV2 instead of using Optional fields
--let EvArgV2 = EvArg ⩓ { internalType : Text }
--let EventArg = < Arg : EvArg | ArgV2 : EvArgV2 >
let EvArg =
      { indexed : Bool, name : Text, type : Text, internalType : Optional Text }

let Fun =
      { constant : Bool
      , name : Text
      , inputs : List FunArg
      , outputs : List FunArg
      , payable : Bool
      , stateMutability : Text
      , type : Text
      }

let Fallback = { payable : Bool, stateMutability : Text, type : Text }

let Constructor =
      { inputs : List FunArg
      , payable : Bool
      , stateMutability : Text
      , type : Text
      }

let Event = { name : Text, anonymous : Bool, inputs : List EvArg, type : Text }

let Op =
      < Function : Fun
      | Event : Event
      | Constructor : Constructor
      | Fallback : Fallback
      >

let Abi = List Op

let DefEntry
    : Type
    = { mapKey : Natural, mapValue : Text }

let Def
    : Type
    = List DefEntry

let TypeBase
    : Type
    = { def : Def } -- size : Natural,

let Hex =
      { Type = TypeBase ⩓ { _hex : Text }
      , default = { _hex = "", def = [] : Def } -- size = 0,
      }

let Address =
      { Type = TypeBase ⩓ { _address : Text }
      , default = { _address = "0x0", def = [] : Def } -- size = 20,
      }

let Void
    : Type
    = TypeBase ⩓ { _void : Text }

let Math =
      { Type = TypeBase ⩓ { _math : Text }
      , default = { _math = "0", def = [] : Def } -- size = 32,
      }

let Renderer
    : Type
    = { defineMem : Natural → Text → Def
      , noop : Natural → Text
      , callMem : Natural → Text → Text → Text
      , concatDefs : List Def → Def
      , sig : Text → Hex.Type
      , asciiToHex : Text → Hex.Type
      , from : Address.Type
      , num : Natural → Math.Type
      , numToHex : Natural → Math.Type → Hex.Type
      , add : Math.Type → Math.Type → Math.Type
      , sub : Math.Type → Math.Type → Math.Type
      , mul : Math.Type → Math.Type → Math.Type
      , div : Math.Type → Math.Type → Math.Type
      , pow : Math.Type → Math.Type → Math.Type
      , log : Math.Type → Math.Type
      , exp : Math.Type → Math.Type
      , render : List Void → Text
      }

let Backend
    : Type
    = { sendValue : ∀(fun : Fun) → Text
      , sendDef : ∀(fun : Fun) → Text
      , callValue : ∀(fun : Fun) → Text
      , callDef : ∀(fun : Fun) → Text
      , createValue : ∀(constructor : Constructor) → Text
      , createDef : ∀(constructor : Constructor) → Text
      , toOutput : Text → Text → Text
      , toLiteral : Text → Text → Text
      , toListLiteral : Text → Text → Text
      , toHex : Text → Text → Text
      , fromHex : Text → Text → Text
      }

in  { Abi = Abi
    , Op = Op
    , Constructor = Constructor
    , Event = Event
    , Fun = Fun
    , Fallback = Fallback
    , FunArg = FunArg
    , EvArg = EvArg
    , SimpleArg = SimpleArg
    , SimpleArgV2 = SimpleArgV2
    , ComplexArg = ComplexArg
    , ComplexArgV2 = ComplexArgV2
    , Renderer = Renderer
    , Backend = Backend
    , TypeBase = TypeBase
    , Hex = Hex
    , Math = Math
    , Address = Address
    , Void = Void
    , DefEntry = DefEntry
    , Def = Def
    }
