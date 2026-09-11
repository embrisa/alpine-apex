"""Plot recorded source/fitted skeletons and native frames, without pose synthesis."""
import json
from pathlib import Path
import sys
sys.path.insert(0,str(Path(__file__).resolve().parents[1]/'.tools/motion-plots'))
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
from PIL import Image
from steep_motion_evidence import vector,visual_folder

ROOT = Path(__file__).resolve().parents[1]
BASE = ROOT/'artifacts/steep_motion_gameplay'
LINKS = [('Hips','Spine02'),('Spine02','Spine01'),('Spine01','Spine'),
         ('Spine','neck'),('neck','Head')]
for side in ('Right','Left'):
    LINKS += [(a if a in ('Hips','Spine') else side+a,side+b) for a,b in
              [('Hips','UpLeg'),('UpLeg','Leg'),('Leg','Foot'),('Spine','Shoulder'),
               ('Shoulder','Arm'),('Arm','ForeArm'),('ForeArm','Hand')]]


def skeleton(ax, points, color, alpha=1):
    for parent,child in LINKS:
        if parent not in points or child not in points: continue
        a,b = vector(points[parent]),vector(points[child])
        ax.plot([-a[2],-b[2]],[a[1],b[1]],'-o',color=color,alpha=alpha,lw=2,ms=3)
    ax.set(xlim=(-1.15,.60),ylim=(0,1.70),aspect='equal')
    ax.grid(alpha=.12)
    ax.set_xlabel('equipment-space forward (m)')
    ax.set_ylabel('equipment-space height (m)')


def main():
    requests = [('neutral_glide',30),('tuck_to_turn',24),('edge_change',45),('safety_grab',30),('mute_grab',30)]
    plt.rcParams.update({'font.size':9,'figure.facecolor':'#f3f6f8','axes.facecolor':'#ffffff'})
    fig,axes = plt.subplots(len(requests),3,figsize=(15,18),gridspec_kw={'width_ratios':[1,1,1.8]},layout='constrained')
    for row_index,(name,frame) in enumerate(requests):
        trace = json.loads((BASE/'after_visual'/f'{name}_motion.json').read_text())['trace'][frame]
        skeleton(axes[row_index,0],trace['requested'],'#009baa')
        skeleton(axes[row_index,1],trace['requested'],'#009baa',.20)
        skeleton(axes[row_index,1],trace['joints'],'#d87521')
        for foot in ('LeftFoot','RightFoot'):
            p = vector(trace['joints'][foot])
            axes[row_index,1].scatter([-p[2]],[p[1]],marker='s',s=35,color='#264253',zorder=4)
        picture = Image.open(BASE/'after_visual'/f'{name}_side'/f'{frame:04d}.jpg')
        axes[row_index,2].imshow(picture); axes[row_index,2].axis('off')
        axes[row_index,0].set_title(name.replace('_',' ')+' / source before fitting')
        d = trace['diagnostics']
        axes[row_index,1].set_title('Fitted / pelvis %.1f cm / grip %.1f mm' % (100*d.get('pelvis_fit_m',0),1000*d.get('grip_reach_error_m',0)))
        axes[row_index,2].set_title('Production game / same sample at %.2f s' % trace['seconds'])
    fig.suptitle('Retarget → binding/limb fitting → actual v13 gameplay\nRecorded 60 Hz motion, 120 Hz simulation, 30 Hz evidence samples. Cyan: unconstrained. Orange: fitted. Squares: physical ankles.',fontsize=14)
    fig.savefig(BASE/'fitting-review.png',dpi=140)
    plt.close(fig)
    # Contact sheets retain chronological ordering for temporal review; source
    # frame numbers remain explicit and the full 30 FPS videos are separate.
    for name in ('edge_change','prepared_hop','safety_grab','mute_grab','flip_release','switch_flip'):
        fig,axes = plt.subplots(3,4,figsize=(16,8),layout='constrained')
        folder = visual_folder('after',name)
        records = json.loads((folder/f'{name}_motion.json').read_text())['trace']
        ids = [round(i*(len(records)-1)/11) for i in range(12)]
        for ax,index in zip(axes.flat,ids):
            ax.imshow(Image.open(folder/f'{name}_side'/f'{index:04d}.jpg'))
            ax.set_title('%.2f s / frame %d' % (index/30,index)); ax.axis('off')
        fig.suptitle(name.replace('_',' ')+' / chronological native gameplay frames')
        fig.savefig(BASE/f'{name}-sequence.jpg',dpi=115)
        plt.close(fig)
    print('Plotted fitting evidence and six chronological native sequences')


if __name__ == '__main__': main()
