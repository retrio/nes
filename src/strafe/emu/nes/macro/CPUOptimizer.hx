package strafe.emu.nes.macro;

import haxe.macro.Expr;
import haxe.macro.ExprTools;
import haxe.macro.Context;
import strafe.emu.nes.OpCode;


class CPUOptimizer
{
	public static function build()
	{
		var fields = haxe.macro.Context.getBuildFields().map(optimizeFields);
		return fields;
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
						//case EVars([{name: "code"}]):
						//	expr.expr = EBlock([]);

						case EMeta({name:"execute"}, e):
							expr.expr = optimizeExecute(e);

						default: {}
					}
				}
			default: {}
		}

		strafe.macro.Optimizer.simplify(e);

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
							if (OpCode.opCodeNames[code] == caseName)
							{
								// this byte represents this operation
								var substitutedExpr = //strafe.macro.Optimizer.simplify(
									strafe.macro.Optimizer.substituteVariable(
										inlineAddrMode(caseExpr.expr), "mode", CInt(Std.string(OpCode.getAddressingMode(byte))));//);

								newCases.push({values: [{expr:EConst(CInt(Std.string(byte))), pos:val.pos}],
									expr: substitutedExpr});
							}
						}
					}
				}

				return ESwitch({expr: EConst(CIdent("byte")), pos: e.pos}, newCases, edef);

			default:
				throw "Unexpected expression with execute metadata; should be opcode switch";
		}
	}

	static function inlineAddrMode(e:Expr):Expr
	{
		switch(e.expr)
		{
			case EBlock(exprs):
				var toRemove:Array<Expr> = [];

				for (expr in exprs)
				{
					switch (expr.expr)
					{
						case EBinop(OpAssign, {expr: EConst(CIdent("mode"))}, _):
							toRemove.push(expr);

						default: {}
					}
				}

				for (i in toRemove)
					exprs.remove(i);
			default: {}
		}
		return e;
	}
}
