"""Publication figures from sealed measurements. No browser rendering required."""
from __future__ import annotations
import argparse,csv,json,shutil
from pathlib import Path
import numpy as np
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
from matplotlib import font_manager,ticker
from run_experiments import CONFIGS,digest

COLORS=['#1d63b7','#d7b475','#c47d0e','#795000']
LABELS=['Software','Iterative · staged','Iterative · fused','Parallel · fused']
SHORT=['Software','Iterative\nstaged','Iterative\nfused','Parallel\nfused']

def read_csv(path):
    rows=list(csv.DictReader(path.open()))
    for row in rows:
        for key,value in row.items():
            try: row[key]=float(value) if '.' in value else int(value)
            except (ValueError,TypeError): pass
    return rows

def select(rows,**filters): return [r for r in rows if all(r[k]==v for k,v in filters.items())]
def median(rows,key='cycles'): return float(np.median([r[key] for r in rows]))
def panel(ax,title,ylabel=None,xlabel=None):
    ax.set_title(title,loc='left',fontweight='bold',fontsize=12,pad=14)
    if ylabel: ax.set_ylabel(ylabel,labelpad=9)
    if xlabel: ax.set_xlabel(xlabel,labelpad=8)
    ax.spines[['top','right']].set_visible(False)
    ax.spines[['left','bottom']].set_color('#aaaaaa')
    ax.grid(axis='y',color='#e5e5e5',linewidth=.6); ax.set_axisbelow(True)
    ax.tick_params(length=3,color='#aaaaaa')

def save(fig,out,name):
    fig.savefig(out/f'{name}.svg',bbox_inches='tight',facecolor='white',metadata={'Date':None,'Creator':'RISC-NPU research/plot_results.py'})
    fig.savefig(out/f'{name}.png',dpi=240,bbox_inches='tight',facecolor='white')
    plt.close(fig)

def main():
    ap=argparse.ArgumentParser(); ap.add_argument('--run',type=Path,required=True)
    ap.add_argument('--verification',type=Path,required=True); ap.add_argument('--synthesis',type=Path)
    ap.add_argument('--article',type=Path,required=True); args=ap.parse_args()
    manifest=json.loads((args.run/'manifest.json').read_text()); assert manifest['status']=='complete'
    verification_manifest=json.loads((args.verification/'manifest.json').read_text())
    assert verification_manifest['status']=='complete'
    assert digest(args.verification/'quantization.csv')==verification_manifest['quantization_sha256']
    assert digest(args.verification/'verification.log')==verification_manifest['log_sha256']
    assert digest(args.run/'results.csv')==manifest['results_sha256']
    rows=read_csv(args.run/'results.csv'); out=args.article/'assets'/'figures'; out.mkdir(parents=True,exist_ok=True)
    data=args.article/'assets'/'data'; data.mkdir(parents=True,exist_ok=True)
    for name in ['results.csv','manifest.json']: shutil.copy2(args.run/name,data/('kernel-'+name))
    for name in ['quantization.csv','verification.log','manifest.json']: shutil.copy2(args.verification/name,data/('arithmetic-'+name))
    for p in [Path('C:/Windows/Fonts/arial.ttf'),Path('C:/Windows/Fonts/georgia.ttf')]:
        if p.exists(): font_manager.fontManager.addfont(str(p))
    plt.rcParams.update({'font.family':'Arial','font.size':11,'axes.labelsize':11,'xtick.labelsize':10,'ytick.labelsize':10,
        'legend.fontsize':10,'svg.fonttype':'none','svg.hashsalt':'risc-npu-research-v2','axes.titlecolor':'#222222',
        'text.color':'#333333','axes.labelcolor':'#333333','xtick.color':'#555555','ytick.color':'#555555',
        'lines.linewidth':1.7,'lines.markersize':5,'figure.constrained_layout.use':True})
    ns=[1,4,8,16,32,64,96]
    fig,axes=plt.subplots(1,2,figsize=(10,4.15),gridspec_kw={'width_ratios':[1.15,1]})
    for i,config in enumerate(CONFIGS):
        groups=[select(rows,n=n,m=1,family='full',configuration=config) for n in ns]
        mid=np.array([median(g) for g in groups]); low=np.array([min(r['cycles'] for r in g) for g in groups]); high=np.array([max(r['cycles'] for r in g) for g in groups])
        axes[0].plot(ns,mid,color=COLORS[i],marker=['o','s','D','^'][i],label=LABELS[i])
        axes[0].fill_between(ns,low,high,color=COLORS[i],alpha=.1,linewidth=0)
        if i:
            ratios=[[s['cycles']/median(groups[j]) for s in select(rows,n=n,m=1,family='full',configuration='software')] for j,n in enumerate(ns)]
            axes[1].plot(ns,[np.median(g) for g in ratios],color=COLORS[i],marker=['o','s','D','^'][i],label=LABELS[i])
            axes[1].fill_between(ns,[min(g) for g in ratios],[max(g) for g in ratios],color=COLORS[i],alpha=.1,linewidth=0)
    panel(axes[0],'a   Complete signed dot product','Kernel cycles · logarithmic scale','Dot-product length N')
    axes[0].set_yscale('log'); axes[0].set_ylim(15,30000); axes[0].set_xticks([1,16,32,64,96])
    panel(axes[1],'b   Benefit at the program boundary','Software / hardware cycles','Dot-product length N')
    axes[1].set_ylim(0,20); axes[1].set_xticks([1,16,32,64,96]); axes[1].axhline(1,color='#777777',ls=':',lw=1)
    handles,labels=axes[0].get_legend_handles_labels(); fig.legend(handles,labels,loc='outside lower center',ncol=4,frameon=False)
    save(fig,out,'01-scaling')

    categories=['fetch','memory','scalar','setup','wait']
    catlabels=['Fetch','RAM instruction phases','Scalar / issue / control','NPU initialization','NPU wait']
    catcolors=['#d7d7d7','#9bb8d4','#6b7b87','#ecd6aa','#c47d0e']
    sample=[select(rows,n=64,m=1,family='full',seed=1729,configuration=c)[0] for c in CONFIGS]
    fig,axes=plt.subplots(1,2,figsize=(10,4.6),gridspec_kw={'width_ratios':[1,1.13]})
    for ax,records in zip(axes,[sample,sample[1:]]):
        left=np.zeros(len(records)); y=np.arange(len(records))
        for cat,color,label in zip(categories,catcolors,catlabels):
            vals=np.array([r[cat] for r in records]); ax.barh(y,vals,left=left,color=color,height=.57,label=label,edgecolor='white',linewidth=.6); left+=vals
        ax.set_yticks(y,[LABELS[CONFIGS.index(r['configuration'])] for r in records]); ax.invert_yaxis()
        for pos,r in enumerate(records): ax.text(r['cycles']+max(left)*.025,pos,f'{r["cycles"]:,}',va='center',fontsize=10)
        ax.set_xlim(0,max(left)*1.2); ax.grid(False); ax.grid(axis='x',color='#eeeeee',lw=.6); ax.set_axisbelow(True)
    panel(axes[0],'a   Same accounting, all four variants',xlabel='Cycles · N = 64, seed 1729')
    panel(axes[1],'b   Hardware detail, expanded scale',xlabel='Cycles · same measurement')
    handles,labels=axes[0].get_legend_handles_labels(); fig.legend(handles,labels,loc='outside lower center',ncol=3,frameon=False,fontsize=9)
    save(fig,out,'02-cycle-budget')

    sparse=select(rows,n=64,m=1,configuration='software'); sparse=[r for r in sparse if str(r['family']).startswith('density_')]
    hw=select(rows,n=64,m=1,family='full',configuration='parallel_fused')[0]['cycles']
    density=np.linspace(0,1,400); model=12+64*(9+density*(141+12*1024/255))
    fig,axes=plt.subplots(1,2,figsize=(10,4.05))
    panel(axes[0],'a   Arithmetic work depends on the data','Cycles per coefficient','Realized nonzero weights (%)')
    axes[0].plot(density*100,model/64,color=COLORS[0],ls='--',lw=1,label='Software · analytical expectation')
    axes[0].scatter([r['weight_density']*100 for r in sparse],[r['cycles']/64 for r in sparse],s=24,facecolor='white',edgecolor=COLORS[0],lw=1.2,zorder=3,label='Software · measured RTL')
    axes[0].axhline(hw/64,color=COLORS[3],lw=1.7,label='Parallel · measured RTL'); axes[0].set_ylim(0,215); axes[0].set_xlim(-2,102); axes[0].legend(loc='upper left',frameon=False,fontsize=9)
    panel(axes[1],'b   The low-density crossover','Software / parallel cycles','Realized nonzero weights (%)')
    axes[1].axhspan(0,1,color='#e8f0fb',zorder=0); axes[1].axhspan(1,2.1,color='#fdf3e3',zorder=0)
    axes[1].plot(density*100,model/hw,color='#777777',ls='--',lw=1)
    axes[1].scatter([r['weight_density']*100 for r in sparse],[r['cycles']/hw for r in sparse],s=30,color=COLORS[0],edgecolor='white',linewidth=.5,zorder=3)
    axes[1].axhline(1,color='#555555',lw=1); axes[1].set_xlim(-.2,7); axes[1].set_ylim(0,2.1)
    axes[1].text(6.7,.19,'Software wins',ha='right',color=COLORS[0],fontsize=10)
    axes[1].text(6.7,1.86,'Parallel wins',ha='right',color=COLORS[3],fontsize=10)
    save(fig,out,'03-sparsity')

    shapes=[(64,1),(8,4),(16,4),(16,8),(32,4)]
    fig,axes=plt.subplots(1,2,figsize=(10,4.4))
    x=np.arange(len(shapes)); warm=[];cold=[]
    for n,m in shapes:
        sw=select(rows,n=n,m=m,family='full',configuration='software'); hp=select(rows,n=n,m=m,family='full',configuration='parallel_fused')
        warm.append(median(sw)/median(hp)); cold.append(median(sw,'cold')/median(hp,'cold'))
    axes[0].bar(x-.17,warm,width=.32,color=COLORS[3],label='Kernel only'); axes[0].bar(x+.17,cold,width=.32,color=COLORS[1],label='Reset release + input setup + kernel')
    axes[0].set_xticks(x,['64-dot','4 × 8','4 × 16','8 × 16','4 × 32']); axes[0].set_ylim(0,20); axes[0].legend(frameon=False,loc='upper left',fontsize=9)
    panel(axes[0],'a   Setup changes the headline','Software / parallel cycles','Vector or matrix shape (M × N)')
    for config,i in [('software',0),('parallel_fused',3)]:
        values=[median(select(rows,n=n,m=1,family='full',configuration=config),'kernel_words')*4 for n in ns]
        axes[1].plot(ns,values,color=COLORS[i],marker='o',label=LABELS[i])
        axes[1].annotate(f'{int(values[-1]):,} B',(ns[-1],values[-1]),xytext=(-5,8),textcoords='offset points',ha='right',color=COLORS[i],fontsize=10)
    panel(axes[1],'b   Static kernel size is also a cost','Kernel instruction bytes · log scale','Dot-product length N')
    axes[1].set_yscale('log'); axes[1].set_ylim(10,80000); axes[1].set_xticks([1,16,32,64,96]); axes[1].legend(loc='upper left',frameon=False)
    save(fig,out,'04-boundaries')

    qrows=read_csv(args.verification/'quantization.csv'); xs=np.array([r['accumulator'] for r in qrows])
    fig,axes=plt.subplots(1,2,figsize=(10,3.9))
    for ax in axes:
        ax.plot(xs,xs/8,color='#888888',ls='--',lw=1,label='Exact division by 8 · reference')
        ax.step(xs,[r['signed_int8'] for r in qrows],where='post',color=COLORS[0],label='Signed INT8 · measured')
        ax.step(xs,[r['relu_int8'] for r in qrows],where='post',color=COLORS[2],label='ReLU INT8 · measured')
    panel(axes[0],'a   Explicit output conversion','Quantized output','Signed accumulator before conversion')
    axes[0].set_xlim(-1024,1024); axes[0].set_ylim(-145,145); axes[0].set_xticks([-1024,-512,0,512,1024]); axes[0].legend(loc='upper left',frameon=False,fontsize=9)
    panel(axes[1],'b   Negative shifts round downward','Quantized output','Accumulator · detail around zero')
    axes[1].set_xlim(-18,26); axes[1].set_ylim(-3.8,4.4); axes[1].set_xticks([-16,-8,0,8,16,24]); axes[1].set_yticks([-3,-2,-1,0,1,2,3,4])
    axes[1].annotate('−5 >> 3 = −1',xy=(-5,-1),xytext=(-13,2.6),arrowprops={'arrowstyle':'->','color':'#555555','lw':.8},fontsize=10)
    save(fig,out,'06-numerics')

    summary={'kernel_cases':len(rows),'verified_kernel_outputs':manifest['verified_outputs'],'run_id':args.run.name,
             'verification_id':args.verification.name,'n64':sample,'shapes':[{'n':n,'m':m,'warm_speedup':a,'cold_speedup':b} for (n,m),a,b in zip(shapes,warm,cold)]}
    if args.synthesis:
        sm=json.loads((args.synthesis/'manifest.json').read_text()); assert sm['status']=='complete'
        assert digest(args.synthesis/'results.csv')==sm['results_sha256']
        fits=read_csv(args.synthesis/'results.csv'); summary['fits']=fits; summary['synthesis_id']=args.synthesis.name
        for name in ['results.csv','manifest.json']: shutil.copy2(args.synthesis/name,data/('synthesis-'+name))
        fig,axes=plt.subplots(1,2,figsize=(10,4.3))
        for i,config in enumerate(CONFIGS):
            f=select(fits,configuration=config); vals=[r['logic_elements'] for r in f]
            axes[0].bar(i,np.median(vals),color=COLORS[i],width=.56,alpha=.9)
            axes[0].scatter(i+np.linspace(-.12,.12,len(f)),vals,color='#333333',s=17,zorder=4)
            axes[0].text(i,max(vals)+45,f'{np.median(vals):,.0f}',ha='center',fontsize=10)
            mhz=[r['fmax_mhz_slow85'] for r in f]
            axes[1].scatter(i+np.linspace(-.12,.12,len(f)),mhz,color=COLORS[i],s=35,edgecolor='white',linewidth=.6,zorder=4)
            axes[1].hlines(np.median(mhz),i-.24,i+.24,color=COLORS[i],lw=1.5)
        panel(axes[0],'a   Logic cost of the complete core','Fitted logic elements')
        axes[0].set_ylim(0,1450); axes[0].set_xticks(range(4),SHORT)
        panel(axes[1],'b   Post-fit clock-frequency estimates','Slow 1.2 V, 85 °C Fmax (MHz)')
        axes[1].axhline(50,color='#888888',ls='--',lw=1); axes[1].text(3.4,50.3,'50 MHz target',ha='right',fontsize=9,color='#777777')
        axes[1].set_ylim(45,65); axes[1].set_xticks(range(4),SHORT)
        save(fig,out,'05-physical-cost')
    (data/'study-summary.json').write_text(json.dumps(summary,indent=2))
    print(json.dumps({k:v for k,v in summary.items() if k not in ['n64','fits']},indent=2))

if __name__=='__main__': main()
