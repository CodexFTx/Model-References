# Copyright (c) 2021, NVIDIA CORPORATION. All rights reserved.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
###############################################################################
# Copyright (C) 2021 Habana Labs, Ltd. an Intel Company
# All Rights Reserved.
#
# Unauthorized copying of this file or any element(s) within it, via any medium
# is strictly prohibited.
# This file contains Habana Labs, Ltd. proprietary and confidential information
# and is subject to the confidentiality and license agreements under which it
# was provided.
#
###############################################################################


import torch.nn as nn
from models.dice import DiceLoss
from monai.losses import FocalLoss


class Loss(nn.Module):
    def __init__(self, focal):
        super(Loss, self).__init__()
        self.dice = DiceLoss(include_background=False, softmax=True, to_onehot_y=True, batch=True)
        self.focal = FocalLoss(gamma=2.0)
        self.cross_entropy = nn.CrossEntropyLoss()
        self.use_focal = focal

    def forward(self, y_pred, y_true):
        loss = self.dice(y_pred, y_true)
        if self.use_focal:
            loss += self.focal(y_pred, y_true)
        else:
            loss += self.cross_entropy(y_pred, y_true[:, 0].long())
        return loss
