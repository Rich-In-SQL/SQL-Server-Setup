# SQL Setup

This script is a work in progress, it will form the base of best practice for setting up of a new SQL Server after installation. 

## Script Features 

* Ability to run the script in test mode (No changes applied)
* Ability to rename SA account
* Ability to change SA password 
* Ability to change default, Data & Log file locations (Requires a instance restart)
* Creation of a database mail operator 
* Ability to install the SQL Server Version reference table
* Ability to change the Agent Log location
* Ability to change the max server memory setting
* Ability to change the MAXDOP setting
* Ability to enable the DAC
* Ability to enable compressed backups by default

The script will also do the following 

* Warn you if it can't find Brent Ozar's tools 
* Warn you if it can't find Ola Hallengren's tools 
