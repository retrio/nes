from pyquery import PyQuery
import re

alpha = re.compile("[a-zA-Z]")


sections = {}
section_name = re.compile('NAME=\"([A-Z]{3})\"')
commands = {}

with open("6502table.html") as input_file:
    store = None
    for line in input_file:
        if '<H3' in line: store = section_name.findall(line)[0]
        if not store: continue
        if not store in sections: sections[store] = ''
        sections[store] += line
    for op in sections:
        p = PyQuery(sections[op])
        table = p("table")[1]
        rows = table.findall("tr")
        for tr in rows[1:]:
            tds = tr.findall("td")
            i = int(tds[1].find("center").text.strip().lstrip("$"), 16)
            md = ''.join(alpha.findall(tds[0].find("a").text))
            ticks = int(tds[3].text.split()[0])
            commands[i] = (op, md, ticks)

    for k, (op, md, ticks) in sorted(commands.items()):
        hx = hex(k)[2:].upper()
        if (len(hx) < 2): hx = "0" + hx
        hx = "0x" + hx
        print "case " + hx + ": { code=OpCodes." + op + ";",
        if (md and not md in ("Implied", "Absolute")): print "mode=AddressingModes." + md + ";",
        if (ticks != 2): print "ticks=%s;" % ticks,
        print "}"