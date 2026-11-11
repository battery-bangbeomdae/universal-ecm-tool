function tests=testEISOutliers
tests=functiontests(localfunctions);
end
function setupOnce(t)
t.TestData.Root=fileparts(fileparts(mfilename('fullpath')));addpath(t.TestData.Root);
end
function testCleanCurvesKept(t)
f=logspace(4,-3,90)';w=2*pi*f;o=uecm.defaults();
for z={.01+.02./(1+1i*w*.05)+.04./(1+1i*w*5),.01+.04./(1+(1i*w*.5).^.7)+.001*(1-1i)./sqrt(w)}
 r=uecm.screenEIS(f,real(z{1}),imag(z{1}),o);verifyFalse(t,any(r.StatisticalOutlier));
end
end
function testIsolatedSpikeAndEndpoints(t)
f=logspace(3,-2,75)';z=.01+.03./(1+1i*2*pi*f*2);o=uecm.defaults();o.EISModels="RC";o.EISAutoWarburg=false;
for ix={30,[1,2]}
 bad=z;bad(ix{1})=bad(ix{1})+.05-.02i;r=uecm.screenEIS(f,real(bad),imag(bad),o);verifyEqual(t,find(r.StatisticalOutlier),ix{1}(:));
 a=uecm.fitEIS(f,real(bad),imag(bad),o);verifyEqual(t,a.Parameters.Rs_Ohm,.01,'RelTol',.001);verifyEqual(t,a.Parameters.Rct_Ohm,.03,'RelTol',.001);verifyEqual(t,a.ExcludedOutlierCount,numel(ix{1}));
end
end
function testRealImageSpectrum(t)
T=readtable(fullfile(t.TestData.Root,'examples','REAL_D010_eis_12spectra.csv'),'TextType','string');T=T(T.spectrum_id==T.spectrum_id(1),:);o=uecm.defaults();r=uecm.screenEIS(T.freq_Hz,T.R_real_Ohm,T.R_img_Ohm,o);verifyTrue(t,all(r.StatisticalOutlier([2,3])));verifyFalse(t,any(r.StatisticalOutlier(72:end)));verifyEqual(t,nnz(r.PositiveImaginary),18);
end
function testDisabledAndAudit(t)
f=logspace(3,-2,75)';z=.01+.03./(1+1i*2*pi*f*2);z(30)=z(30)+.05-.02i;z(1)=.01+.003i;o=uecm.defaults();o.EISOutlierFilter=false;
r=uecm.screenEIS(f,real(z),imag(z),o);verifyFalse(t,any(r.StatisticalOutlier));verifyTrue(t,r.PositiveImaginary(1));
fig=uifigure('Visible','off');c=onCleanup(@()delete(fig));ax=uiaxes(fig);hold(ax,'on');uecm.plotExcludedEIS(ax,struct('Preprocessing',r));h=findall(ax,'Tag','EISExcluded_positive_imaginary');verifyEqual(t,numel(h),1);verifyEqual(t,string(h.Marker),"x");
uecm.zoomNyquist(ax,z(2:29));verifyLessThan(t,diff(ax.XLim),.1);
end

function testExclusionLimit(t)
f=logspace(3,-2,75)';z=.01+.03./(1+1i*2*pi*f*2);z(30)=z(30)+.05-.02i;o=uecm.defaults();o.EISOutlierMaxFraction=0;
r=uecm.screenEIS(f,real(z),imag(z),o);verifyFalse(t,any(r.StatisticalOutlier));verifyGreaterThan(t,strlength(r.Properties.UserData.Warning),0);
end
function testUnstableRepeatedFrequency(t)
f=logspace(3,-2,75)';z=.01+.03./(1+1i*2*pi*f*2);fr=[f;repmat(f(end),7,1)];zr=[z;z(end)+.003*exp(1i*(1:7)')];o=uecm.defaults();
r=uecm.screenEIS(fr,real(zr),imag(zr),o);verifyTrue(t,all(r.UnstableRepeat(75:end)));verifyEqual(t,unique(r.Reason(75:end)),"unstable_repeated_frequency");
o.EISRepeatFilter=false;r=uecm.screenEIS(fr,real(zr),imag(zr),o);verifyFalse(t,any(r.UnstableRepeat));
r=uecm.screenEIS(fr,real([z;repmat(z(end),7,1)]),imag([z;repmat(z(end),7,1)]),uecm.defaults());verifyFalse(t,any(r.UnstableRepeat));
end
