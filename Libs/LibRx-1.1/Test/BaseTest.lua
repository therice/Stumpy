loadfile("Test/WowXmlParser.lua")()

-- basic dependencies required by LibUtil
function LoadDependencies()
    ParseXmlAndLoad('Libs/LibDeflate/LibDeflate.xml')
    ParseXmlAndLoad('Libs/LibClass-1.0/LibClass-1.0.xml')
    ParseXmlAndLoad('Libs/LibLogging-1.1/LibLogging-1.1.xml')
    ParseXmlAndLoad('Libs/LibUtil-1.1/LibUtil-1.1.xml')
    ParseXmlAndLoad('Libs/LibRx-1.1/LibRx-1.1.xml')
end