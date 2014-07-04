from cisco import *

b = CLI('show interface brief', False)

#Get list formatted output
list = b.get_output()

#Find interfaces that are up
matching = [s for s in list if "Eth1" in s]

for s in matching:
	#Get list of interfaces one by one and list output of 'show run <interface>'
	y = s.split(' ')[0]
	x = CLI('show run interface ' + y, False)	
	list1 = x.get_output()

	#Find all interfaces with explicitly trunked VLANs
	match = [s for s in list1 if "switchport trunk allowed" in s]
	match1 = [s for s in list1 if "description" in s]

	#Extract VLANs
	for v in match:
		z = v.split('vlan')[1]
		#Extract description
		for v in match1:
			w = v.split('description')[1]
			#Print interface, description and VLAN, separated by comma
			print y + ',' + "\"" + w + "\"" + ',' + "\"" + z + "\""



