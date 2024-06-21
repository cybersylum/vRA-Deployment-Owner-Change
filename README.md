# vRA-Deployment-Owner-Change
 Performs a bulk owner change for all deployments.  Each deployment will have the owner changed to a common user or group.
 <p>
 Notes:
 <ul>
 <li>This script is best suited for a one-time bulk change.   It may be better to perform this task during blueprint or onboarding deployments for everyday use.  An example of this (using ABX Action) is https://vmwarecode.com/2021/11/24/vra-cloud-add-the-users-in-projects-and-change-the-owner-of-deployment-dynamically-using-python-abx-action/
 <li>The script has a rate limit feature included which is designed to pause after updating a pre-configured number of deployments.  This is a measure
 to help prevent overloading the Aria Automation server.  Updating a deployment will update every resource attached and can be taxing.
 <li>Snapshots and test environments are your friend.  Use them.
 </ul>

Disclaimer:  This script was obtained from https://github.com/cybersylum<br>
<ul>
<li>You are free to use or modify this code for your own purposes</li>
<li>No warranty or support for this code is provided or implied</li>  
<li>Use this at your own risk</li>
<li>Testing is <b>highly</b> recommended.
</ul>
<br>

<p>All scripts require Poweshell and PowerVRA 6.x+ - https://github.com/jakkulabs/PowervRA</p>

