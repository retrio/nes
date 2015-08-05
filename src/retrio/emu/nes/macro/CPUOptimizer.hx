package retrio.emu.nes.macro;

import haxe.macro.Expr;
import haxe.macro.ExprTools;
import haxe.macro.Context;
import retrio.macro.Optimizer;
import retrio.emu.nes.OpCode;


class CPUOptimizer
{
	static var f1:Map<AddressingMode, String> = [
		AddressingMode.Accumulator => "a",
		AddressingMode.Immediate => "imm()",
		AddressingMode.ZeroPage => "read(zpg())",
		AddressingMode.ZeroPageX => "read(zpx())",
		AddressingMode.ZeroPageY => "read(zpy())",
		AddressingMode.Relative => "read(rel())",
		AddressingMode.Absolute => "read(abs())",
		AddressingMode.AbsoluteX => "read(abx())",
		AddressingMode.AbsoluteY => "read(aby())",
		AddressingMode.Indirect => "read(ind())",
		AddressingMode.IndirectX => "read(inx())",
		AddressingMode.IndirectY => "read(iny())",
	];

	static var f2:Map<AddressingMode, String> = [
		AddressingMode.Accumulator => "a",
		AddressingMode.Immediate => "imm()",
		AddressingMode.ZeroPage => "zpg()",
		AddressingMode.ZeroPageX => "zpx()",
		AddressingMode.ZeroPageY => "zpy()",
		AddressingMode.Relative => "rel()",
		AddressingMode.Absolute => "abs()",
		AddressingMode.AbsoluteX => "abx()",
		AddressingMode.AbsoluteY => "aby()",
		AddressingMode.Indirect => "ind()",
		AddressingMode.IndirectX => "inx()",
		AddressingMode.IndirectY => "iny()",
	];

	public static function build()
	{
		var buildFields = haxe.macro.Context.getBuildFields();
		retrio.macro.Optimizer.findInlinedFunctions(buildFields);
		return buildFields.map(optimizeFields);
	}

	static function optimizeFields(field:Field):Field
	{
		switch(field.kind)
		{
			case FFun(f):
				if (field.name == 'runCycle')
				{
					optimizeRunCycle(f.expr);
					trace(ExprTools.toString(f.expr));
				}

			default: {}
		}

		return field;
	}

	/**
	 * Transform the giant switch statement from an operation switch to an opcode
	 * byte switch to avoid extra branching.
	 */
	static function optimizeRunCycle(e:Expr)
	{
		switch(e.expr)
		{
			case EBlock(exprs):
				for (expr in exprs)
				{
					switch (expr.expr)
					{
						case EMeta({name:"execute"}, e):
							expr.expr = optimizeExecute(e);

						default: {}
					}
				}
			default: {}
		}

		retrio.macro.Optimizer.simplify(e);

		ExprTools.iter(e, optimizeRunCycle);
	}

	static function optimizeExecute(e:Expr):ExprDef
	{
		switch(e.expr)
		{
			case ESwitch(e, cases, edef):
				var newCases:Array<Case> = [];

				for (caseExpr in cases)
				{
					for (val in caseExpr.values)
					{
						var caseName = switch (val.expr)
						{
							case EConst(CIdent(v)): v;
							default: "";
						}

						//trace(ExprTools.getValue());
						for (byte in 0 ... 0x100)
						{
							var code = OpCode.getCode(byte);
							var ticks = OpCode.getTicks(byte);
							var mode = OpCode.getAddressingMode(byte);

							if (OpCode.opCodeNames[code] == caseName)
							{
								newCases.push({values: [{expr:EConst(CInt("0x" + StringTools.hex(byte, 2).toLowerCase())), pos:val.pos}],
									expr: clean(clean(inlineAddrMode(caseExpr.expr, mode, ticks, OpCode.opCodeNames[code]), mode), mode)});
							}
						}
					}
				}

				return ESwitch({expr: EConst(CIdent("byte")), pos: e.pos}, newCases, edef);

			default:
				throw "Unexpected expression with execute metadata; should be opcode switch";
		}
	}

	static function inlineAddrMode(e:Expr, mode:AddressingMode, ticks:Int, op:String):Expr
	{
		switch(e.expr)
		{
			case EBlock(exprs):
				exprs = exprs.copy();

				var i = 0;
				while (i < exprs.length)
				{
					var expr = exprs[i];
					switch (expr.expr)
					{
						case EBinop(OpAssign, {expr: EConst(CIdent("mode"))}, _):
							exprs[i] = Context.parse('trace("$op")', Context.currentPos());
							exprs.insert(i+1, Context.parse('ticks = $ticks', Context.currentPos()));

						default: {}
					}
					++i;
				}

				return {expr: EBlock(exprs), pos: e.pos};

			default: {}
		}
		return e;
	}

	static function clean(e:Expr, mode:AddressingMode):Expr
	{
		switch(e.expr)
		{
			case ECall({expr: EConst(CIdent("storeValue"))}, [a, b, c]):
				switch(mode)
				{
					case AddressingMode.Accumulator:
						return {expr: EBinop(OpAssign, {expr: EConst(CIdent("a")), pos:e.pos}, {expr: EConst(CIdent("value")), pos: e.pos}), pos: e.pos};

					default:
						return {expr: ECall({expr: EConst(CIdent("write")), pos: e.pos}, [b, c]), pos:e.pos};
				}

			case ECall({expr: EConst(CIdent("getValue"))}, [{expr: EConst(CIdent("mode"))}]):
				return Context.parse(f1[mode], e.pos);

			case ECall({expr: EConst(CIdent("getAddress"))}, [{expr: EConst(CIdent("mode"))}]):
				return Context.parse(f2[mode], e.pos);

			case ECall(a, [b, {expr: EConst(CIdent("mode"))}]):
				return {expr: ECall(a, [b]), pos: e.pos};

			default:
				return ExprTools.map(e, function(e) return clean(e, mode));
		}
	}
}
