let Text/concatMapSep = ./Prelude/Text/concatMapSep

let Text/concatMap = ./Prelude/Text/concatMap

let Text/concatSep = ./Prelude/Text/concatSep

let List/map = ./Prelude/List/map

let List/filter = ./Prelude/List/filter

let schema = ./abiSchema.dhall

let backend = ./backend.dhall

let FunArg = schema.FunArg

let SimpleArg = schema.SimpleArg

let SimpleArgV2 = schema.SimpleArgV2

let ComplexArg = schema.ComplexArg

let ComplexArgV2 = schema.ComplexArgV2

let SimpleIArg = { index : Natural, value : SimpleArg }

let isConstructor
    : schema.Op → Bool
    =   λ(op : schema.Op)
      → merge
          { Function = λ(_ : schema.Fun) → False
          , Fallback = λ(_ : schema.Fallback) → False
          , Event = λ(_ : schema.Event) → False
          , Constructor = λ(_ : schema.Constructor) → True
          }
          op

let isntConstructor
    : schema.Op → Bool
    =   λ(op : schema.Op)
      → (isConstructor op) == False

let hasConstructor
    : List schema.Op → Bool
    =   λ(ops : List schema.Op)
      → Optional/fold
          schema.Op
          (List/head schema.Op (List/filter schema.Op isConstructor ops))
          Bool
          (λ(_ : schema.Op) → True)
          False

let toSimpleArg
    : FunArg → SimpleArg
    =   λ(arg : FunArg)
      → merge
          { Simple = λ(arg : SimpleArg) → arg.{ name, type }
          , SimpleV2 = λ(arg : SimpleArgV2) → arg.{ name, type }
          , Complex = λ(arg : ComplexArg) → arg.{ name, type }
          , ComplexV2 = λ(arg : ComplexArgV2) → arg.{ name, type }
          }
          arg

let toSimpleArgs
    : List FunArg → List SimpleArg
    = List/map FunArg SimpleArg toSimpleArg

let funIndexedArgToDhallFun
    : SimpleIArg → Text
    =   λ(iarg : SimpleIArg)
      → let index = Natural/show iarg.index
        let type = iarg.value.type
        in
        ''
        (arg${index} : types.evm/${type}/Type)
        → ''
        -- → let tc0 = assert : lte arg${index}.size types.size/${type} === True in ''

let funArgsToDhallFun
    : Text → List FunArg → Text
    =   λ(prfx : Text)
      → λ(args : List FunArg)
      → Text/concatMap
          SimpleIArg
          (λ(arg : SimpleIArg) → prfx ++ (funIndexedArgToDhallFun arg))
          (List/indexed SimpleArg (toSimpleArgs args))

let funReturnToDhallType
    : List FunArg → Text
    =   λ(outputs : List FunArg)
      → Optional/fold
          SimpleArg
          (List/head SimpleArg (toSimpleArgs outputs))
          Text
          (λ(arg : SimpleArg) → arg.type)
          "void"

let funArgsSignature
    : List FunArg → Text
    =   λ(args : List FunArg)
      → Text/concatMapSep
          "-"
          SimpleArg
          (λ(arg : SimpleArg) → arg.type)
          (toSimpleArgs args)

let funSignature
    : List Text → List FunArg → Text
    =   λ(names : List Text)
      → λ(args : List FunArg)
      →     Text/concatSep
              "/"
              (   names
                # Optional/fold
                    FunArg
                    (List/head FunArg args)
                    (List Text)
                    (λ(arg : FunArg) → [ "" ])
                    ([] : List Text)
              )
        ++  funArgsSignature args

let createFunType
    : Text → schema.Constructor → Text
    =   λ(name : Text)
      → λ(constructor : schema.Constructor)
      → ''
        ${funSignature [ "create" ] constructor.inputs} :
           ${funArgsToDhallFun "∀" constructor.inputs}
            ∀(next : InstType → Plan)
          → ∀(plan : SinglePlan)
          → ∀(tag : Natural)
          → Run
        ''

let createFun
    : Text → schema.Constructor → Text
    =   λ(name : Text)
      → λ(constructor : schema.Constructor)
      → ''
        ${funSignature [ "create" ] constructor.inputs} =
           ${funArgsToDhallFun "λ" constructor.inputs}
            λ(next : InstType → Plan)
          → λ(plan : SinglePlan)
          → λ(tag : Natural)
          → next
              (build
                  (types.evm/address
                    (${backend.createValue constructor})
                    (${backend.createDef constructor})
                  ))
              plan
              (tag + 1)
        ''

let sendType
    : schema.Fun → Text
    =   λ(fun : schema.Fun)
      → ''
        ${funSignature [ "send", fun.name ] fun.inputs} :
            ${funArgsToDhallFun "∀" fun.inputs}
            ∀(next : SinglePlan)
          → ∀(tag : Natural)
          → Run
        ''

let send
    : schema.Fun → Text
    =   λ(fun : schema.Fun)
      → ''
        ${funSignature [ "send", fun.name ] fun.inputs} =
            ${funArgsToDhallFun "λ" fun.inputs}
            λ(next : SinglePlan)
          → λ(tag : Natural)
          → [ (types.evm/void
                (${backend.sendValue fun})
                (${backend.sendDef fun}))
            ] # next (tag + 1)
        ''

let callType
    : schema.Fun → Text
    =   λ(fun : schema.Fun)
      → ''
        ${funSignature [ "call", fun.name ] fun.inputs} :
            ${funArgsToDhallFun "∀" fun.inputs}
            ∀(next :
                types.evm/${funReturnToDhallType fun.outputs}/Type
              → Plan
            )
          → ∀(plan : SinglePlan)
          → ∀(tag : Natural)
          → Run
        ''

let call
    : schema.Fun → Text
    =   λ(fun : schema.Fun)
      → let  returnType = funReturnToDhallType fun.outputs
        in
        ''
        ${funSignature [ "call", fun.name ] fun.inputs} =
            ${funArgsToDhallFun "λ" fun.inputs}
            λ(next :
                types.evm/${returnType}/Type
              → Plan
            )
          → λ(plan : SinglePlan)
          → λ(tag : Natural)
          → next
              (types.evm/${returnType}
                (${backend.callValue fun})
                (${backend.callDef fun}))
              plan
              (tag + 1)
        ''

let defaultConstructor =
      schema.Op.Constructor
        { inputs = [] : List FunArg
        , payable = False
        , stateMutability = ""
        , type = "constructor"
        }

let abiOpToDhallType
    : Text → schema.Op → Text
    =   λ(name : Text)
      → λ(op : schema.Op)
      → merge
          { Function =
              λ(fun : schema.Fun) → "${sendType fun}\n, ${callType fun}"
          , Fallback = λ(fallback : schema.Fallback) → "fallback : {}"
          , Event = λ(event : schema.Event) → "event/${event.name} : {}"
          , Constructor = createFunType name
          }
          op

let abiOpToDhall
    : Text → schema.Op → Text
    =   λ(name : Text)
      → λ(op : schema.Op)
      → merge
          { Function =
              λ(fun : schema.Fun) → "${send fun}\n, ${call fun}"
          , Fallback = λ(fallback : schema.Fallback) → "fallback = {=}"
          , Event = λ(event : schema.Event) → "event/${event.name} = {=}"
          , Constructor = createFun name
          }
          op

let abiToDhall
    : Text → Text → schema.Abi → Text
    =   λ(prefix : Text)
      → λ(name : Text)
      → λ(ops : schema.Abi)
      → ''
        let lte = ./Prelude/Natural/lessThanEqual

        let types = ./types

        let lib = ./lib

        let Def = lib.Def

        let Void = lib.Void

        let Run = lib.Run

        let SinglePlan = lib.SinglePlan

        let Plan = lib.Plan

        let renderer = ./renderer

        let prefix = "${prefix}"

        let name = "${name}"

        let InstType
            : Type
            = { address : types.Address
                ${Text/concatMap
                  schema.Op
                  (λ(op : schema.Op) → ", " ++ (abiOpToDhallType name op))
                  (List/filter schema.Op isntConstructor ops)
                  }
              }

        let build
            : ∀(address : types.Address) → InstType
            = λ(address : types.Address)
            → { address = address
                ${Text/concatMap
                  schema.Op
                  (λ(op : schema.Op) → ", " ++ (abiOpToDhall name op))
                  (List/filter schema.Op isntConstructor ops)
                  }
              }

        in  { ${name} = InstType
            , ${name}/build = build
            , ${name}/${Text/concatMapSep
                ''

                , ${name}/''
                schema.Op
                (abiOpToDhall name)
                ( if hasConstructor ops
                  then  (List/filter schema.Op isConstructor ops)
                  else  [ defaultConstructor ]
                )}
            }
        ''

in  abiToDhall
