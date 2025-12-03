unit Interp;

{$mode ObjFPC}{$H+}

interface

uses
  Classes, SysUtils;

type
  // ===== Expression Types =====
  ExprTag = (etNum, etStr, etId);

  ExprC = record
    tag: ExprTag;
    case ExprTag of
      etNum: (num: Double);
      etStr: (str: ShortString);
      etId:  (name: ShortString);
  end;

  // ===== Value Types =====
  ValueTag = (vtNum, vtStr, vtBool);

  Value = record
    tag: ValueTag;
    case ValueTag of
      vtNum: (num: Double);
      vtStr: (str: ShortString);
      vtBool: (bool: Boolean);
  end;

  // ===== Environment (linked list) =====
  PEnv = ^Env;

  Env = record
    name: ShortString;
    value: Value;
    next: PEnv;
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

// ===== Interp (basic version with only Num, String, Id) =====
function Interp(const e: ExprC; env: PEnv): Value;
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

  else
    raise InterpError.Create('interp: unknown expression tag');
  end;
end;

// ===== Tests =====
procedure TestInterp;
var
  env: PEnv;
  e: ExprC;
  v, bound: Value;
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
end;

end.


