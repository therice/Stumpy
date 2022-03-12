loadfile("Test/WowXmlParser.lua")()

-- basic dependencies required by LibUtil
function LoadDependencies()
	ParseXmlAndLoad('Libs/LibDeflate/LibDeflate.xml')
	ParseXmlAndLoad('Libs/LibClass-1.0/LibClass-1.0.xml')
	ParseXmlAndLoad('Libs/LibLogging-1.1/LibLogging-1.1.xml')
	ParseXmlAndLoad('Libs/LibUtil-1.2/LibUtil-1.2.xml')
	ParseXmlAndLoad('Libs/LibTotem-1.0/LibTotem-1.0.xml')
end