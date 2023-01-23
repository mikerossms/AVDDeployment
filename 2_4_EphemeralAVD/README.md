# coming soon - still being built.

# 2.4 Ephemeral AVD Deployment

![Infrastructure for Ephemeral AVD](../Diagrams/2_4_EphemeralAVD.png)

## What this does

This deploys an Ephemeral AVD.  Ephemeral AVD works by creating and destroying the machines on demand.  This is based on VMSS connected to the Host Pool rather than individual machines.

VMSS based scaling has a number of advantages and disadvantages.  Make sure it is the right solution for you:

**Advantages**
- Only active resources remain deployed - no cost for VM hard disks etc in deallocated machines
- Scaling limited only by subscription/datacentre limits
- All new instales are clean and built from a golden image
- Issue machines can be simply removed from the VMSS/HostPool (scale down) and re-added (scale up)
- Very fast to re-deploy
- Very fast to scale up (all VMSS instances built in parallel)
- Easy for Maintenance management - change the image, wait for maintenance window, scale to zero, upgrade VMSS, scale back up, done.

**Disadvantages**
- Patch management really needs to be done in the golden image, so regular image builds are required (can be automated easily enough though)
- AD objects need to be carefully managed.  By default the VMSS will create a new object for every scale up operation which can result in thousands of old objects in AD if not managed
- It can take a few minutes for a new VMSS instance to come online, so good planning around peak loads is required
- Difficult to put an instance into quarantine for investigative purposes


# Deploying the Infrastructure

.\1_DeployEphemeralAVD.ps1 -localenv dev -dryrun $false -dologin $false