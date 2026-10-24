from PIL import Image
import numpy as np
import collections

for name in ['home_active', 'home_inactive', 'calendar_active', 'calendar_inactive']:
    im = Image.open(f'assets/figma_ref/clean_{name}.png')
    a = np.array(im)[:, :, 3]
    print(name, collections.Counter(a.flatten()).most_common(5))
