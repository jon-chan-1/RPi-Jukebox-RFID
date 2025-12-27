# MIT License
#
# Copyright (c) 2025
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in all
# copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE.

import logging
import subprocess
import jukebox.plugs as plugs
import jukebox.cfghandler
from components.battery_monitor import BatteryMonitorBase

logger = logging.getLogger('jb.battmon')

batt_mon = None


class battmon_lifepo4wered(BatteryMonitorBase.BattmonBase):
    '''Battery Monitor for LiFePO4wered UPS using CLI'''

    def __init__(self, cfg):
        super().__init__(cfg, logger)
        logger.info("LiFePO4wered battery monitor initialized")

        # Override voltage thresholds for LiFePO4 chemistry
        # LiFePO4 has different voltage curve than Li-ion
        # Note: LiFePO4wered hardware will force shutdown at 2950mV
        self.soc_cc = {
            2500: 0,    # Empty
            2800: 5,
            2950: 10,   # Hardware shutdown threshold
            3000: 15,
            3100: 25,
            3200: 50,
            3250: 70,
            3300: 85,
            3400: 95,
            3600: 100   # Full
        }

        self.ok_voltage = 3200
        self.warning_voltage = 3100
        # Set above hardware shutdown (2950mV) to avoid software shutdown
        # Let LiFePO4wered hardware handle the actual shutdown
        self.shutdown_voltage = 3000

    def init_batt_mon_hw(self, num, denom):
        """Initialize hardware - not needed for LiFePO4wered as it uses CLI"""
        try:
            # Test if lifepo4wered-cli is available
            result = subprocess.run(
                ['lifepo4wered-cli', 'get', 'vbat'],
                capture_output=True,
                text=True,
                timeout=5
            )
            if result.returncode != 0:
                logger.error("lifepo4wered-cli not found or not working")
                raise RuntimeError("LiFePO4wered CLI not available")
            logger.info("LiFePO4wered CLI detected and working")
        except Exception as e:
            logger.error(f"Failed to initialize LiFePO4wered: {e}")
            raise

    def get_batt_voltage(self):
        """Read battery voltage from LiFePO4wered using CLI"""
        try:
            result = subprocess.run(
                ['lifepo4wered-cli', 'get', 'vbat'],
                capture_output=True,
                text=True,
                timeout=5
            )
            if result.returncode == 0:
                voltage_mv = int(result.stdout.strip())
                return voltage_mv
            else:
                logger.error(f"Failed to read battery voltage: {result.stderr}")
                return 0
        except subprocess.TimeoutExpired:
            logger.error("Timeout reading battery voltage")
            return 0
        except Exception as e:
            logger.error(f"Error reading battery voltage: {e}")
            return 0


@plugs.finalize
def finalize():
    global batt_mon
    cfg = jukebox.cfghandler.get_handler('jukebox')
    batt_mon = battmon_lifepo4wered(cfg)
    plugs.register(batt_mon, name='batt_mon')


@plugs.atexit
def atexit(**ignored_kwargs):
    global batt_mon
    batt_mon.status_thread.cancel()
