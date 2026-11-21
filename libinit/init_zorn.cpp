/*
   Copyright (c) 2015, The Linux Foundation. All rights reserved.
   Copyright (C) 2020 The OmniRom Project.
   Copyright (C) 2026 AERA Recovery Project contributors.
   Redistribution and use in source and binary forms, with or without
   modification, are permitted provided that the following conditions are
   met:
    * Redistributions of source code must retain the above copyright
      notice, this list of conditions and the following disclaimer.
    * Redistributions in binary form must reproduce the above
      copyright notice, this list of conditions and the following
      disclaimer in the documentation and/or other materials provided
      with the distribution.
    * Neither the name of The Linux Foundation nor the names of its
      contributors may be used to endorse or promote products derived
      from this software without specific prior written permission.
   THIS SOFTWARE IS PROVIDED "AS IS" AND ANY EXPRESS OR IMPLIED
   WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF
   MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NON-INFRINGEMENT
   ARE DISCLAIMED.  IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS
   BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
   CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
   SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR
   BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY,
   WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE
   OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN
   IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */

#include <string>
#include <android-base/logging.h>
#include <android-base/properties.h>
#define _REALLY_INCLUDE_SYS__SYSTEM_PROPERTIES_H_
#include <sys/_system_properties.h>

using android::base::GetProperty;

namespace {

void property_override(const std::string& name, const std::string& value) {
    prop_info* pi = const_cast<prop_info*>(__system_property_find(name.c_str()));
    if (pi != nullptr) {
        __system_property_update(pi, value.c_str(), value.size());
    } else {
        int rc = __system_property_add(name.c_str(), name.size(), value.c_str(), value.size());
        if (rc < 0) {
            LOG(ERROR) << "property_override(\"" << name << "\", \"" << value
                       << "\") failed: __system_property_add returned " << rc;
        }
    }
}

void model_property_override(const std::string& device,
                             const std::string& name,
                             const std::string& brand,
                             const std::string& model) {
    static const char* const kPartitions[] = {
        "", "odm.", "vendor.", "product.", "system_ext.", "system.", "bootimage."
    };

    property_override("ro.build.product", device);
    for (const char* part : kPartitions) {
        const std::string prefix = std::string("ro.product.") + part;
        property_override(prefix + "device", device);
        property_override(prefix + "name", name);
        property_override(prefix + "brand", brand);
        property_override(prefix + "model", model);
    }
}

}  // namespace

void vendor_load_properties() {
    const std::string hwc = GetProperty("ro.boot.hwc", "");

    if (hwc == "CN") {
        model_property_override("zorn", "zorn", "Redmi", "Redmi K80");
    } else {
        model_property_override("zorn", "zorn_global", "POCO", "POCO F7 Pro");
    }
}
