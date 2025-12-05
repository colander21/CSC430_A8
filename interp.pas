unit Interp;

{$mode ObjFPC}{$H+}

interface

uses
  Classes, SysUtils;

type
  // ===== Expression Types =====
  ExprTag = (etNum, etStr, etId, etIf, etLam, etApp);

  PExpr = ^ExprC;

  ExprC = record
    tag: ExprTag;
    case ExprTag of
      etNum: (num: Double);
      etStr: (str: ShortString);
      etId:  (name: ShortString);
      etIf: (
        condExpr : PExpr;
        thenExpr : PExpr;
        elseExpr : PExpr
      );
      etLam: (
        param: ShortString;
        body: PExpr
      );
      etApp: (
        funcExpr: PExpr;
        argExpr: PExpr
      );
  end;

  // ===== Value Types =====
  ValueTag = (vtNum, vtStr, vtBool, vtClosure);

  PEnv = ^Env;
  PClosure = ^Closure;

  Value = record
    tag: ValueTag;
    case ValueTag of
      vtNum: (num: Double);
      vtStr: (str: ShortString);
      vtBool: (bool: Boolean);
      vtClosure: (closure: PClosure);
  end;

  // ===== Environment (linked list) =====

  Env = record
    name: ShortString;
    value: Value;
    next: PEnv;
  end;

  Closure = record
    param: ShortString;
    body: PExpr;
    env: PEnv;
  end;

function Extend(env: PEnv; const name: ShortString; const v: Value): PEnv;
function Lookup(env: PEnv; const name: ShortString): Value;
function Interp(const e: ExprC; env: PEnv): Value;
procedure TestInterp;

implementation

type
  InterpError = class(Exception)
  end;

// ===== Helper: print values =====
procedure PrintValue(const v: Value);
begin
  case v.tag of
    vtNum:
      Writeln('Num: ', v.num:0:2);
    vtStr:
      Writeln('Str: ', v.str);
    vtBool:
      if v.bool then
        Writeln('Bool: true')
      else
        Writeln('Bool: false');
  else
    Writeln('Unknown value tag');
  end;
end;

// ===== Environment functions =====
function Extend(env: PEnv; const name: ShortString; const v: Value): PEnv;
var
  newEnv: PEnv;
begin
  New(newEnv);
  newEnv^.name := name;
  newEnv^.value := v;
  newEnv^.next := env;
  Result := newEnv;
end;

function Lookup(env: PEnv; const name: ShortString): Value;
var
  cur: PEnv;
begin
  cur := env;
  while cur <> nil do
  begin
    if cur^.name = name then
      Exit(cur^.value);
    cur := cur^.next;
  end;
  raise InterpError.CreateFmt('unbound identifier: %s', [name]);
end;

// ===== Interp (basic version with only Num, String, Id, If) =====
function Interp(const e: ExprC; env: PEnv): Value;
var
  condVal: Value;
  clos: PClosure;
  funcVal, argVal: Value;
  newEnv: PEnv;
begin
  case e.tag of
    etNum:
      begin
        Result.tag := vtNum;
        Result.num := e.num;
      end;

    etStr:
      begin
        Result.tag := vtStr;
        Result.str := e.str;
      end;

    etId:
      begin
        Result := Lookup(env, e.name);
      end;

    etIf:
      begin
        condVal := Interp(e.condExpr^, env);

        if condVal.tag <> vtBool then
          raise InterpError.Create('interp: if condition is not boolean');

        if condVal.bool then
          Result := Interp(e.thenExpr^, env)
        else
          Result := Interp(e.elseExpr^, env);
      end;

    etLam:
      begin
        New(clos);
        clos^.param := e.param;
        clos^.body := e.body;
        clos^.env := env;

        Result.tag := vtClosure;
        Result.closure := clos;
      end;

    etApp:
      begin
        funcVal := Interp(e.funcExpr^, env);
        if funcVal.tag <> vtClosure then
          raise InterpError.Create('interp: function position is not a closure');

        argVal := Interp(e.argExpr^, env);

        newEnv := Extend(funcVal.closure^.env, funcVal.closure^.param, argVal);

        Result := Interp(funcVal.closure^.body^, newEnv);
      end;
  else
    raise InterpError.Create('interp: unknown expression tag');
  end;
end;

function TopLevelEnv: PEnv;
var v: Value; env: PEnv;
begin
  env := nil;

  v.tag := vtBool; v.bool := True;
  env := Extend(env, 'true', v);

  v.tag := vtBool; v.bool := False;
  env := Extend(env, 'false', v);

  Result := env;
end;

function Serialize(const v: Value): ShortString;
begin
  case v.tag of
    vtNum:  Str(v.num:0:0, Result);
    vtStr:  Result := '"' + v.str + '"';
    vtBool: if v.bool then Result := 'true' else Result := 'false';
    vtClosure: Result := '#<procedure>';
  else
    Result := '#<unknown>';
  end;
end;

function TopInterp(const e: ExprC): ShortString;
var v: Value;
begin
v := Interp(e, TopLevelEnv);
Result := Serialize(v);
end;

// ===== Tests =====
procedure TestInterp;
var
  env: PEnv;
  e: ExprC;
  v, bound: Value;
  condExpr, thenExpr, elseExpr: PExpr;
  bodyExpr: PExpr;
  clos: PClosure;
begin
  Writeln('--- TestInterp ---');

  env := nil;

  // Test 1: Number literal
  e.tag := etNum;
  e.num := 44;
  v := Interp(e, env);

  Assert(v.tag = vtNum, 'Num literal: wrong tag');
  Assert(Abs(v.num - 44.0) < 0.0001, 'Num literal: wrong value');

  // Test 2: String literal
  e.tag := etStr;
  e.str := 'test';
  v := Interp(e, env);

  Assert(v.tag = vtStr, 'String literal: wrong tag');
  Assert(v.str = 'test', 'String literal: wrong value');

  // Test 3: Bound identifier
  bound.tag := vtNum;
  bound.num := 10.5;
  env := Extend(nil, 'x', bound);

  e.tag := etId;
  e.name := 'x';
  v := Interp(e, env);

  Assert(v.tag = vtNum, 'Id lookup: wrong tag');
  Assert(Abs(v.num - 10.5) < 0.0001, 'Id lookup: wrong value');

  // Test 4: Boolean lookup
  bound.tag := vtBool;
  bound.bool := True;
  env := Extend(env, 'b', bound);

  e.tag := etId;
  e.name := 'b';
  v := Interp(e, env);

  Assert(v.tag = vtBool, 'Bool lookup: wrong tag');
  Assert(v.bool = True, 'Bool lookup: wrong value');

  Writeln('All tests passed.');

  // Test 5: if w/ true condition
  // env only has one binding where cond = true

  env := nil;
  bound.tag := vtBool;
  bound.bool := True;
  env := Extend(env, 'cond', bound);

  New(condExpr);
  condExpr^.tag := etId;
  condExpr^.name := 'cond';

  New(thenExpr);
  thenExpr^.tag := etNum;
  thenExpr^.num := 44;

  New(elseExpr);
  elseExpr^.tag := etNum;
  elseExpr^.num := 99;

  e.tag := etIf;
  e.condExpr := condExpr;
  e.thenExpr := thenExpr;
  e.elseExpr := elseExpr;

  v := Interp(e, env);
  
  Assert(v.tag = vtNum, 'if true: wrong tag');
  Assert(Abs(v.num - 44.0) < 0.01, 'if true: wrong value');

  // Test 6: Basic closure value construction

  New(bodyExpr);
  bodyExpr^.tag := etNum;
  bodyExpr^.num := 0;

  New(clos);
  clos^.param := 'x';
  clos^.body := bodyExpr;
  clos^.env := nil;

  v.tag := vtClosure;
  v.closure := clos;

  Assert(v.tag = vtClosure, 'closure: wrong tag');

  // Test 7: interp of lambda produces a closure

  env := nil;

  New(bodyExpr);
  bodyExpr^.tag := etNum;
  bodyExpr^.num := 5;

  e.tag := etLam;
  e.param := 'x';
  e.body := bodyExpr;

  v := Interp(e, env);

  Assert(v.tag = vtClosure, 'lambda: result not closure');
  Assert(v.closure^.param = 'x', 'lambda: wrong param name');
  Assert(v.closure^.body^.tag = etNum, 'lambda: wrong body tag');
  Assert(Abs(v.closure^.body^.num - 5.0) < 0.01, 'lambda: wrong body value');

  // Test 8: applying identity lambda
  // (lambda (x) : x) 42 => 42

  env := nil;

  New(bodyExpr);
  bodyExpr^.tag := etId;
  bodyExpr^.name := 'x';

  New(condExpr);
  condExpr^.tag := etLam;
  condExpr^.param := 'x';
  condExpr^.body := bodyExpr;

  New(thenExpr);
  thenExpr^.tag := etNum;
  thenExpr^.num := 42;

  e.tag := etApp;
  e.funcExpr := condExpr;
  e.argExpr := thenExpr;

  v := Interp(e, env);

  Assert(v.tag = vtNum, 'app: wrong result tag');
  Assert(Abs(v.num - 42.0) < 0.01, 'app: wrong result value');

  // Test 9: proving Lexical Scoping (closure captures defining env)
  // say that env has y = 10 s.t. (lambda (x) : y) 999 => 10

  env := nil;
  bound.tag := vtNum;
  bound.num := 10.0;
  env := Extend(env, 'y', bound);

  New(bodyExpr);
  bodyExpr^.tag := etId;
  bodyExpr^.name := 'y';

  New(condExpr);
  condExpr^.tag := etLam;
  condExpr^.param := 'x';
  condExpr^.body := bodyExpr;

  New(thenExpr);
  thenExpr^.tag := etNum;
  thenExpr^.num := 999.0;

  e.tag := etApp;
  e.funcExpr := condExpr;
  e.argExpr := thenExpr;

  v := Interp(e, env);

  Assert(v.tag = vtNum, 'closure env: wrong result tag');
  Assert(Abs(v.num - 10) < 0.01, 'closure env: wrong captured value');

  // Test 10: serialize function
  v.tag := vtNum;
  v.num := 42.0;
  Assert(Serialize(v) = '42', 'serialize wrong output for 42');

  v.tag := vtClosure;
  v.closure := clos; 
  Assert(Serialize(v) = '#<procedure>', 'serialize wrong for closure');


  // Test 11: TopLevelEnv test bindings
  env := TopLevelEnv;
  v := Lookup(env, 'true');
  Assert(v.tag = vtBool, 'TopLevelEnv true has wrong tag');
  Assert(v.bool = True, 'TopLevelEnv true has wrong value');

  v := Lookup(env, 'false');
  Assert(v.tag = vtBool, 'TopLevelEnv false has wrong tag');
  Assert(v.bool = False, 'TopLevelEnv false has wrong value');

  // Test 12: TopInterp
  e.tag := etNum;
  e.num := 42.0;
  Assert(TopInterp(e) = '42', 'TopInterp wrong output for 42');

end;

end.


